;;; Smoke test — proves s7 builds and evaluates correctly.
;;; A test script exits 0 on success and non-zero on failure; that exit code
;;; is what `make test` and CI check.

(define failures 0)

(define (check name expected actual)
  (if (equal? expected actual)
      (format *stdout* "  ok   ~A~%" name)
      (begin
        (set! failures (+ failures 1))
        (format *stdout* "  FAIL ~A: expected ~S, got ~S~%" name expected actual))))

(check "arithmetic"      10        (apply + '(1 2 3 4)))
(check "list ops"        '(1 4 9)  (map (lambda (x) (* x x)) '(1 2 3)))
(check "string"          "s7!"     (string-append "s7" "!"))
(check "tail recursion"  500500    (let loop ((i 1) (acc 0))
                                     (if (> i 1000) acc (loop (+ i 1) (+ acc i)))))
(check "r7rs feature"    #t        (and (provided? 's7) #t))

(exit (if (= failures 0) 0 1))
