(IN-PACKAGE "ACL2")

(DEFUN FOO (X) (CONS X X))

(DEFTHM FOO-PROP (EQUAL (CAR (FOO X)) X))

(DEFUN BAR (X) (FOO X))

(DEFUN H (X) (BAR X))
