structure MB_Monitor :> MB_Monitor =
struct

open ProcessMultiplexor Holmake_tools

val five_sec = Time.fromSeconds 5
val W_EXITED = Posix.Process.W_EXITED

fun Pstatus_to_string st =
  let
    open Posix.Process
  in
    case st of
        W_EXITED => "OK"
      | W_EXITSTATUS w8 => Word8.toString w8
      | W_SIGNALED s => "Signal "^SysWord.toString (Posix.Signal.toWord s)
      | W_STOPPED s => "Stopped "^SysWord.toString (Posix.Signal.toWord s)
  end

(* thanks to Rob Arthan for this function *)
fun strmIsTTY (outstream : TextIO.outstream) =
  let
    val (wr as TextPrimIO.WR{ioDesc,...},buf) =
	TextIO.StreamIO.getWriter(TextIO.getOutstream outstream);
    val _ =
        TextIO.setOutstream (outstream, TextIO.StreamIO.mkOutstream(wr, buf))
  in
    case ioDesc of
	NONE => false
      | SOME desc => (OS.IO.kind desc = OS.IO.Kind.tty)
  end

val green = boldgreen
val red = boldred

fun nextchar #"|" = #"/"
  | nextchar #"/" = #"-"
  | nextchar #"-" = #"\\"
  | nextchar #"\\" = #"|"
  | nextchar c = c

fun stallstr "|" = "!"
  | stallstr ":" = "|"
  | stallstr "." = ":"
  | stallstr "!" = "!!"
  | stallstr "!!" = "!!!"
  | stallstr "!!!" = red "!!!"
  | stallstr s = s

datatype monitor_status = MRunning of char
                        | Stalling of Time.time
fun statusString (MRunning c) = StringCvt.padLeft #" " 3 (str c) ^ " "
  | statusString (Stalling t) =
    let
      val numSecs = Time.toSeconds t
      val n_s = LargeInt.toString numSecs
    in
      if numSecs < 5 then "    "
      else if numSecs < 10 then "  " ^ n_s ^ " "
      else if numSecs < 30 then " " ^ boldyellow n_s ^ " "
      else if numSecs < 1000 then red (StringCvt.padLeft #" " 3 n_s) ^ " "
      else red "!!! "
    end

fun rtrunc n s =
  if String.size s > n then
    "... " ^ String.substring(s, String.size s - (n - 4), n - 4)
  else StringCvt.padRight #" " n s

fun polish0 tag =
  if String.isSuffix "Theory" tag then
    String.substring(tag,0,String.size tag - 6)
  else if String.isSuffix "Theory.sig" tag then
    String.substring(tag,0,String.size tag - 10)
  else if String.isSuffix "Theory.sml" tag then
    String.substring(tag,0,String.size tag - 10)
  else if String.isSuffix "Theory.dat" tag then
    String.substring(tag,0,String.size tag - 10)
  else tag

fun truncate width s =
  if String.size s > width then
    let
      open OS.Path
      val {arcs,isAbs,vol} = fromString s
      fun t s = truncate width s
    in
      if length arcs > 1 andalso String.size (hd arcs) >= 3 then
        t (".. " ^ toString {arcs=tl arcs,isAbs = false, vol = vol})
      else
        let
          val e = case ext s of NONE => "" | SOME s => s
        in
          if String.size e > 2 then t (base s ^ "..")
          else String.substring(s,0,14) ^ ".."
        end
    end
  else s

fun polish s = StringCvt.padRight #" " 16 (truncate 16 (polish0 s))

val cheat_string = "Saved CHEAT _"
val oracle_string = "Saved ORACLE thm _"
val used_cheat_string = "(used CHEAT)"

fun delsml_sfx s =
  if String.isSuffix ".sml" s orelse String.isSuffix ".sig" s then
    String.substring(s, 0, size s - 4)
  else if String.isSuffix "Theory.dat" s then
    String.substring(s, 0, size s - 4)
  else s

fun new {info,warn,genLogFile,keep_going,time_limit} =
  let
    val monitor_map = ref (Binarymap.mkDict String.compare)
    val check_time =
        case time_limit of
            NONE => (fn (_,_,k) => k ())
          | SOME t => (fn (delay,key,k) =>
                          if Time.>(delay,t) then SOME(Kill key) else k())
    fun ttydisplay_map () =
      let
        val _ = print "\r"
      in
        if Binarymap.numItems (!monitor_map) > 1 then
          (Binarymap.app (fn (k,(_,v)) =>
                             print (polish k ^ statusString v))
                         (!monitor_map);
           print CLR_EOL)
        else
          case Binarymap.listItems (!monitor_map) of
              [] => ()
            | (k,((strm,tb),stat)) :: _ =>
              let
                val s = case tailbuffer.last_line tb of NONE => "" | SOME s => s
              in
                print (polish k ^ rtrunc 57 (": " ^ s) ^ " " ^
                       (case stat of
                            Stalling _ => statusString stat
                          | _ => "   "));
                print CLR_EOL
              end
      end
    fun id (s:string) = s
    val (startmsg, infopfx, display_map, green, red, boldyellow, dim, CLR_EOL) =
        if strmIsTTY TextIO.stdOut then
          ((fn s => ()), "\r", ttydisplay_map, green, red, boldyellow, dim,
           CLR_EOL)
        else
          ((fn s => info ("Starting work on " ^ delsml_sfx s)), "",
           (fn () => ()),
           id, id, id, id, "")
    fun stdhandle tag f =
      case Binarymap.peek (!monitor_map, tag) of
          NONE => (warn ("Lost monitor info for "^tag); NONE)
        | SOME info => f info
    fun taginfo tag colour s =
      info (infopfx ^
            StringCvt.padRight #" " (79 - String.size s) (delsml_sfx tag) ^
            colour s ^ CLR_EOL)
    fun monitor msg =
      case msg of
          StartJob (_, tag) =>
          let
            val strm = TextIO.openOut (genLogFile{tag = tag})
            val tb = tailbuffer.new {
                  numlines = 10,
                  patterns = [cheat_string, oracle_string, used_cheat_string]
                }
          in
            monitor_map :=
              Binarymap.insert(!monitor_map, tag, ((strm, tb), MRunning #"|"));
            startmsg tag;
            display_map();
            NONE
          end
        | Output((_, tag), t, chan, msg) =>
          stdhandle tag
            (fn ((strm,tb),stat) =>
                let
                  val stat' = case stat of MRunning c => MRunning (nextchar c)
                                         | Stalling _ => MRunning #"|"
                  open tailbuffer
                in
                  TextIO.output(strm,msg);
                  TextIO.flushOut strm;
                  monitor_map :=
                    Binarymap.insert(!monitor_map, tag,
                                     (((strm,append msg tb), stat')));
                  display_map();
                  NONE
                end)
        | NothingSeen(jkey as (_, tag), {delay,...}) =>
          let
            fun after_check strm stat =
              let
                val stat' =
                    case stat of
                        MRunning c => if Time.>(delay, five_sec) then
                                        Stalling delay
                                      else MRunning c
                      | Stalling _ => Stalling delay
              in
                monitor_map :=
                  Binarymap.insert(!monitor_map, tag, (strm, stat'));
                display_map();
                NONE
              end
          in
            stdhandle
              tag
              (fn (strm,stat) =>
                  check_time (delay, jkey, (fn () => after_check strm stat)))
          end
        | Terminated((_, tag), st, _) =>
          stdhandle tag
            (fn ((strm,tb),stat) =>
                let
                  val {fulllines,lastpartial,patterns_seen} =
                    tailbuffer.output tb
                  fun seen s = Holmake_tools.member s patterns_seen
                  val taginfo = taginfo tag
                  val status_string = Pstatus_to_string st
                in
                  if st = W_EXITED then
                    if seen cheat_string orelse seen used_cheat_string then
                      taginfo boldyellow "CHEATED"
                    else
                      taginfo
                        (if seen oracle_string then boldyellow else green) "OK"
                  else (taginfo red ("FAILED! <" ^ status_string ^ ">");
                        List.app (fn s => info (" " ^ dim s)) fulllines;
                        if lastpartial <> "" then info (" " ^ dim lastpartial)
                        else ());
                  TextIO.closeOut strm;
                  monitor_map := #1 (Binarymap.remove(!monitor_map, tag));
                  display_map();
                  if st = W_EXITED orelse keep_going then NONE
                  else SOME KillAll
                end)
        | MonitorKilled((_, tag), _) =>
          stdhandle tag
            (fn ((strm,tb), stat) =>
                (taginfo tag red "M-KILLED";
                 TextIO.closeOut strm;
                 monitor_map := #1 (Binarymap.remove(!monitor_map, tag));
                 display_map();
                 NONE))
        | _ => NONE
  in
    monitor
  end



end
