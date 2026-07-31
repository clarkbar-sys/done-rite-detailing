;;; A tiny s7 Scheme program. Run it with:
;;;   make build && ./bin/s7 examples/hello.scm
;;; or, using the published container:
;;;   docker run --rm -v "$PWD:/work" -w /work ghcr.io/clarkbar-sys/REPO examples/hello.scm

(define (greet who)
  (string-append "Hello, " who ", from s7 Scheme!"))

(display (greet "world"))
(newline)
