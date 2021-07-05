;; Git overview - A simple overview of many git repositories.
;;
;; This project is licenced under BSD 3-Clause License which follows.
;;
;; Copyright (c) 2021, 1. d4
;; All rights reserved.
;; 
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:
;; 
;; 1. Redistributions of source code must retain the above copyright notice, this
;;   list of conditions and the following disclaimer.
;; 
;; 2. Redistributions in binary form must reproduce the above copyright notice,
;;   this list of conditions and the following disclaimer in the documentation
;;   and/or other materials provided with the distribution.
;; 
;; 3. Neither the name of the copyright holder nor the names of its
;;   contributors may be used to endorse or promote products derived from
;;   this software without specific prior written permission.
;; 
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;
;; ==[ Introduction ]== 
;; 
;; This project arise from the need of a clear view of what is going on in
;; a certain project. So the main question we want to answer are:
;;
;; - What are the last thing everyone did?
;; - What is the situation of the project? Where are developers working now?
;; - What are the latest steps by a developer on the whole project?
;; 
;; To answer those question I wish a tool that does those query for me. The
;; tool should be accessible from anyone so that no one can be excluded or
;; hide from their responsibilities.
;;
;; The user manual (aka README.md) explains the features and requirements
;; for this project. Here we will discuss the design and implementation.
;;
;; ==[ Resolution ]==
;; 
;; In the future I *think* this document should be structured as follows:
;; - Changelogs?
;; - Requirements analysis
;; - Design of the project
;; - Implementation
;;   - Development and debugging notes
;;   - Command line explaination
;;   - Data explaination
;;   - Import explaination
;;   - External webhook explaination
;;   - Server explaination
;;
;; ==[ Notes on data ]==
;; 
;; We would like to structure our database as follow:
;;
;; Authors: **author**, email
;; Repositories: **repository**, name, url
;; Branches: **branch**, repository
;; BranchLabels: **group**, name
;; GroupedBranches: _**branch**_, _**group**_
;; Commits: **hash**, **repository**, _branch_, _author_, comment, timestamp
;;
;; Note: **primary keys**, _external keys_.
;;
;; We will use sql-de-lite as library for sqlite3 as the intended sqlite3
;; is not as egonomic as wanted and need some extra configuration to make
;; it work on all platforms. In addition sql-de-lite some higher order
;; functions we can use already.

(import args
        spiffy
        intarweb
        uri-common
        sql-de-lite
        sxml-serializer
        (chicken io)
        (chicken port)
        (chicken format)
        (chicken string)
        (chicken process)
        (chicken process-context))

;; Version of the software
(define version "git-overview 0.0 by 1dotd4")
(define data-file "./data.sqlite3")

(server-port 6660)


;; Test database is:
;; create table people(email varchar(50) primary key, name varchar(50));
;; insert into people values ('foo@here.net', 'foo');
;; insert into people values ('bar@here.net', 'bar');

;; create table repositories(name varchar(50) primary key , path varchar(100));

(define (cmd-basename path) (format "basename ~A" path))
(define (cmd-git-branch path) (format "git --no-pager --git-dir=~A branch" path))
(define (cmd-git-log-dump path) (format "git --git-dir=~A --no-pager log --branches --tags --remotes --full-history --date-order --format='format:%H%x09%P%x09%at%x09%an%x09%ae%x09%s%x09%D'" path))

(define (import-repository path)
  (call-with-database "./data.sqlite3"
    (lambda (db)
      (begin
        (with-input-from-pipe (cmd-basename path)
          (lambda ()
            (let* ((basename (read-line)))
              (dynamic-wind
                (lambda () '())
                (lambda ()
                  (print (exec
                        (sql db "insert into repositories values (?,?);")
                        basename
                        (format "~A.git" path))))
                (lambda ()
                  (begin 
                    (print "This repository already exists")
                    (close-database db)
                    (exit)))
                ))))))))

(define (populate-repository-information repo)
  (print (cadr repo))
  (print (with-input-from-pipe (cmd-git-branch (cadr repo))
  (lambda () (read-lines))))
    (print (car (with-input-from-pipe (cmd-git-log-dump (cadr repo))
                  (lambda ()
                    (map
                      (lambda (a) 
                        (string-split a "\t" #t))
                      (read-lines)))))))

(define (fetch-repository-data)
  (call-with-database data-file
    (lambda (db)
      (let* ((repositories (query fetch-all (sql db "select * from repositories;"))))
        (map populate-repository-information repositories)))))
      

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
  (format "nav-link text-~A"
    (if (equal? current-page expected)
      "light active"
      "secondary")))

(define (build-people data)
  `(div (@ (class "container"))
    (p (@ (class "text-center text-muted mt-3 small"))
      "Tests a nice team")
    (div (@ (class "row my-3"))
      ,(map data->sxml-card data))))

(define (build-repo data)
  `(div (@ (class "container"))
    (p (@ (class "text-center text-muted mt-3 small"))
      "Tests a busy project")
    (div (@ (class "table-responsive"))
      (table (@ (class "table table-striped table-hover"))
        (thead
          (tr
            ,(map (lambda (x) `(td ,x))
              (car data))))
        (tbody
          ,(map (lambda (x)
                  `(tr 
                      (td ,(car x))
                      ,(map (lambda (y)
                              `(td ,(map data->sxml-compact-card y)))
                            (cdr x))))
            (cdr data)))
          ))))

(define (build-user data)
  `(div (@ (class "container"))
    (form (@ (action "#") (method "POST"))
      (div (@ (class "row my-3"))
        (h2 (@ (class "col my-3")) ,(car data))
        (div (@ (class "col-lg-3 my-3 mx-auto"))
          (div (@ (class "col form-check"))
            (input (@ (class "form-check-input") (type "checkbox") (id "my-fancy-core") (value "selected")))
            (label (@ (class "form-check-label") (for "my-fancy-core")) "my-fancy-core"))
          (div (@ (class "col form-check"))
            (input (@ (class "form-check-input") (type "checkbox") (id "my-fancy-frontend") (value "selected") (checked)))
            (label (@ (class "form-check-label") (for "my-fancy-frontend")) "my-fancy-frontend")))
        (div (@ (class "col-lg-3 my-3 mx-auto"))
          (div (@ (class "col form-check"))
            (input (@ (class "form-check-input") (type "checkbox") (id "stable") (value "selected") (checked)))
            (label (@ (class "form-check-label") (for "stable" )) "stable"))
          (div (@ (class "col form-check"))
            (input (@ (class "form-check-input") (type "checkbox") (id "current") (value "selected")))
            (label (@ (class "form-check-label") (for "current" )) "current"))
          (div (@ (class "col form-check"))
            (input (@ (class "form-check-input") (type "checkbox") (id "add-button") (value "selected") (checked)))
            (label (@ (class "form-check-label") (for "add-button" )) "add-button")))
        (div (@ (class "col-lg my-3 mx-auto"))
          (input (@ (class "btn btn-secondary") (type "submit") (value "Update filter"))))))
    (div (@ (class "table-responsive"))
      (table (@ (class "table table-striped table-hover"))
        (thead
          (tr
            ,(map (lambda (x) `(td ,x))
              '("hash" "repository" "branch" "comment" "date"))))
        (tbody
          (tr
            ,(map (lambda (x)
                    `(tr ;; Refactor this data->row
                      ,(map (lambda (y)
                          `(td ,y))
                        x)))
              (cdr data))))))))

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
        (div (@ (class "navbar navbar-expand-lg navbar-dark bg-dark static-top mb-3"))
          (div (@ (class "container"))
            (a (@ (class "navbar-brand") (href "/"))
              "Git overview - Project X")
            (ul (@ (class "nav ml-auto"))
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
                  (build-repo `(
                    ("Repository" "stable" "feature/new-button" "feature/new-panel")
                    ("our-fancy-core"
                      ( ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data))
                      ( ,(a-sample-data)
                        ,(a-sample-data))
                      ( ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data)))
                    ("our-fancy-frontend"
                      ( ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data))
                      ( ,(a-sample-data)
                        ,(a-sample-data))
                      ( ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data)
                        ,(a-sample-data)))
                    )))
                ((equal? current-page 'user)
                  (build-user '("@1dotd4"
                      ("c0ff33" "my-fancy-frontend" "stable" "release 1.2" "2021-05-13 1037")
                      ("c0ff33" "my-fancy-frontend" "add-button" "finalize button" "2021-05-10 1137")
                      ("c0ff33" "my-fancy-frontend" "add-button" "change color" "2021-05-05 1237")
                      ("c0ff33" "my-fancy-frontend" "add-button" "add button" "2021-05-03 0937")
                      ("c0ff33" "my-fancy-frontend" "stable" "release 1.1" "2021-04-25 1137")
                      ("c0ff33" "my-fancy-frontend" "stable" "release 1.0" "2021-04-01 1537")
                    )))
              ;; '("hash" "repository" "branch" "comment" "date"))))
                (else `(div (@ (class "container"))
                        (p (@ (class "text-center text-muted mt-3 small"))
                            "Page not found."))))
                                                      
        (div (@ (class "container text-secondary text-center my-4 small"))
          (a (@ (class "text-info") (href "https://github.com/1dotd4/go"))
            ,version))

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
          (else
            (send-response status: 'not-found body: )))))

(vhost-map `((".*" . ,handle-greeting)))


;; This is used to choose an operation by options
(define (operation) 'none)

(define opts
  (list (args:make-option (i import) (required: "REPOPATH") "Import from repository at path REPOPATH"
          (set! operation 'import))
        (args:make-option (s serve) #:none "Serve the database"
          (set! operation 'serve))
        (args:make-option (v V version) #:none "Display version"
          (print (version))
          (exit))
        (args:make-option (h help) #:none "Display this text" (usage))))

(define (usage)
  (with-output-to-port (current-error-port)
    (lambda ()
      (print "Usage: " (car (argv)) " [options...] [files...]")
      (newline)
      (print (args:usage opts))
      (print (version))))
  (exit 1))

;; "main"
(receive (options operands)
    (args:parse (command-line-arguments) opts)
  (cond ((equal? operation 'import)
          (print "Will import from " (alist-ref 'import options))
          (import-repository (alist-ref 'import options)))
        ((equal? operation 'serve)
          (print "Will serve the database")
          (start-server))
        (else
          (fetch-repository-data)))) 

