(import spiffy intarweb uri-common
        sxml-serializer)

(server-port 6660)

(define (send-sxml-response sxml)
    (with-headers `((connection close))
                  (lambda ()
                    (write-logged-response)))
    (serialize-sxml sxml
                    output: (response-port (current-response))))

(define (handle-greeting continue)
  (let* ((uri (request-uri (current-request))))
    (cond ((equal? (uri-path uri) '(/ ""))
            (send-response status: 'ok body: "Yes this is the home"))
          ((equal? (uri-path uri) '(/ "greet"))
            (send-response status: 'ok body: "<h1>Hello world</h1>"))
          ((equal? (uri-path uri) '(/ "sxml"))
            (send-sxml-response
              `(html
                 (head
                   (title "Hello there"))
                 (body
                   (h1 "Yo")
                   (p "k")))))
          (else (continue)))))

(vhost-map `((".*" . ,handle-greeting)))

(start-server)
