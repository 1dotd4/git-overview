(import spiffy
        intarweb
        uri-common
        sxml-serializer
        (chicken format)
        )

(server-port 6660)

(define (a-sample-data)
  '("@1dotd4" "feature/new-button" "5 minutes ago."))

(define (send-sxml-response sxml)
    (with-headers `((connection close))
                  (lambda ()
                    (write-logged-response)))
    (serialize-sxml sxml
                    output: (response-port (current-response))))

(define (data->sxml-card data)
  `(div (@ (class "col-lg-3 my-3 mx-auto"))
    (div (@ (class "card"))
      (div (@ (class "card-body"))
        (h5 (@ (class "card-title")) ,(car data))
        (h6 (@ (class "card-subtitle")) ,(cadr data)))
      (div (@ (class "card-footer")) (format "Last update "
                                             ,(caddr data))))))

(define (data->sxml-compact-card data)
  `(div (@ (class "card my-3"))
    (div (@ (class "card-body"))
      (h5 (@ (class "card-title")) ,(car data)))
    (div (@ (class "card-footer"))
      (format "Last update "
              ,(caddr data)))))

(define (activate-nav-button current-page expected)
  (format "nav-link~A"
    (if (equal? current-page expected)
      " active"
      "")))

(define (build-people data)
  `(div (@ (class "container"))
    (p (@ (class "text-center text-muted mt-3 small"))
      "Tests a nice team")
    (div (@ (class "row my-3"))
      ,(map data->sxml-card data))))

(define (build-repo) ;; TODO: refactor
  `(div (@ (class "container"))
    (p (@ (class "text-center text-muted mt-3 small"))
      "Tests a busy project")
    (div (@ (class "table-responsive"))
      (table (@ (class "table table-striped table-hover"))
        (thead
          (tr
            (td "Repository")
            (td "stable")
            (td "feature/a")
            (td "feature/b")))
        (tbody
          (tr
            (td "my-fancy-core")
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  ,(a-sample-data)
                  ,(a-sample-data)
                  )))
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  )))
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  )))
            )
          (tr
            (td "my-fancy-frontend")
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  ,(a-sample-data)
                  ,(a-sample-data)
                  )))
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  )))
            (td
              ,(map data->sxml-compact-card
                `(
                  ,(a-sample-data)
                  )))
            )
          )))))

(define (build-page current-page)
  `(html
      (head
        (meta (@ (charset "utf-8")))
        (title ,(cond ((equal? current-page 'people) "People - Project X")
                      ((equal? current-page 'repo) "Repositories - Project X")
                      ((equal? current-page 'user) "User - Project X")
                      (else "404 - Project X")))
        (meta (@ (name "viewport") (content "width=device-width, initial-scale=1, shrink-to-fit=no")))
        (meta (@ (name "author") (content "1dotd4")))
        (link (@ (href "https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css") (rel "stylesheet") (integrity "sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC") (crossorigin "anonymous"))))
      (body
        (div (@ (class "navbar navbar-expand-lg navbar-dark bg-dark static-top"))
          (div (@ (class "container"))
            (a (@ (class "navbar-brand"))
              "Git overview - project X")
            (ul (@ (class "nav nav-pills ml-auto"))
              (li (@ (class "nav-item"))
                (a (@ (class ,(activate-nav-button current-page 'people))
                      (href "/"))
                  "People"))
              (li (@ (class "nav-item"))
                (a (@ (class ,(activate-nav-button current-page 'repo))
                      (href "repo"))
                  "Repositories"))
              (li (@ (class "nav-item"))
                (a (@ (class ,(activate-nav-button current-page 'user))
                      (href "/user"))
                  "User")))))
        ,(cond ((equal? current-page 'people)
                  (build-people `(
                    ,(a-sample-data)
                    ,(a-sample-data)
                    ,(a-sample-data)
                    ,(a-sample-data)
                    ,(a-sample-data)
                    ,(a-sample-data)
                    ,(a-sample-data)
                    )))
                ((equal? current-page 'repo)
                  (build-repo))
                (else `(div (@ (class "container"))
                        (p (@ (class "text-center text-muted mt-3 small"))
                            "Work in progress."))))
                                                      

      ;; - end body -
      )))


(define (handle-greeting continue)
  (let* ((uri (request-uri (current-request))))
    (cond ((equal? (uri-path uri) '(/ ""))
            (send-sxml-response (build-page 'people)))
          ((equal? (uri-path uri) '(/ "repo"))
            (send-sxml-response (build-page 'repo)))
          ((equal? (uri-path uri) '(/ "user"))
            (send-sxml-response (build-page 'user)))
          ((equal? (uri-path uri) '(/ "greet"))
            (send-response status: 'ok body: "<h1>Hello world</h1>"))
          (else (continue)))))

(vhost-map `((".*" . ,handle-greeting)))

(start-server)
