(import spiffy intarweb uri-common)

(server-port 6660)

(define (handle-greeting continue)
  (let* ((uri (request-uri (current-request))))
    (cond ((equal? (uri-path uri) '(/ ""))
            (send-response status: 'ok body: "Yes this is the home"))
          ((equal? (uri-path uri) '(/ "greet"))
            (send-response status: 'ok body: "<h1>Hello world</h1>"))
          (else (continue)))))

(vhost-map `(("localhost" . ,handle-greeting)))

(start-server)
