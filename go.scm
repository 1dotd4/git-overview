;;;; Git overview - A simple overview of many git repositories.

;; This project is licenced under BSD 3-Clause License which follows.

;; Copyright (c) 2021, 1. d4

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

;;;; 0. Introduction

;;; This project arise from the need of a clear view of what is going on in
;;; a certain project. So the main question we want to answer are:
;;;
;;; - What are the last thing everyone did?
;;; - What is the situation of the project? Where are developers working now?
;;; - What are the latest steps by a developer on the whole project?
;;; 
;;; To answer those question I wish a tool that does those query for me. The
;;; tool should be accessible from anyone so that no one can be excluded or
;;; hide from their responsibilities.
;;;
;;; The user manual (aka README.md) explains the features and requirements
;;; for this project. Here we will discuss the design and implementation.

;;;; 0.1. Index

;;; I. LICENCE
;;; 0. Introduction
;;;   0.1 Index
;;;   0.2 Prelude
;;;   0.3 Known issues
;;; 1. Requirements analysis
;;; 2. Design of the project
;;; 3. Implementation
;;;   3.1 Development and debugging notes
;;; TODO

;;;; 0.2. Prelue
(define-syntax λ
  (syntax-rules ()
    ((_ param body ...) (lambda param body ...))))

(import srfi-1
        sort-combinators
        uri-common
        (chicken io)
        (chicken file)
        (chicken sort)
        (chicken time)
        (chicken format)
        (chicken string)
        (chicken process)
        (chicken time posix))

(define (binary-or a b) (or a b))

(define (cons-unique equals?)
  (lambda (new-element alist)
    (cond ((null? alist) (list new-element))
          ((null? new-element) alist)
          (else
            (if (fold binary-or #f (map (lambda (el) (equals? new-element el)) alist))
              alist
              (cons new-element alist))))))

(define (take-at-most alist most)
  (if (< (length alist) most)
    alist
    (take alist most)))

(define (drop-first alist most)
  (if (< (length alist) most)
    '()
    (drop alist most)))

;;;; 0.3 Known issues

;; - Timezone does not exists because of broken import function
;; - UI is not that nice in /insight

;; TODO: setup security
;; (server-port 443)
;; (spiffy-user "www")
;; (spiffy-group "www")

;; TODO should this be CGI?


;;;; 1. Requirements analysis

;;; The main part of this project is importing, organizing and displaying
;;; commits in a simple and undestandable way which allows to see the real
;;; history of a project composed of many repositories.
;;;
;;; We will leave out of this revision the OAuth APIs for querying for
;;; information a Cloud SCM like GitHub. We will focus on local repositories
;;; that are easy to maintain.
;;; 
;;; The experince should be linear:
;;; 1. install git-overview;
;;; 2. run `git-overview --import path/to/my-repo/` for each repository;
;;; 3. run `git-overview --serve` to check that everything is working;
;;; 4. setup it as a service and add a basic auth in front of it.
;;;
;;; The service will have a homepage and an insight page that display the
;;; commit history with more details.
;;;
;;; In the home page one want to see:
;;; - who pushed last,
;;; - where did she push,
;;; - how time ago did she push.
;;;
;;; In addition one may want to see:
;;; - the commit trimmed to 7 characted.
;;;
;;; In the insight page one want to see latest commits with various
;;; filters:
;;; - commits in the selected repositories,
;;; - commits from the selected people,
;;; - commits after and/or before a selected commit in a temporally,
;;; - commits after and/or before a selected commit in the same branch. 
;;;
;;; This is to help a developer finding the reasons of certain bugs or
;;; fixes found in the code and reconstruct the decision made past in time.

;;;; 2. Design

;;; We will not use SQLite3 because SQL can't traverse graphs efficiently.
;;; We will use S-expressions to store our data which is easier to
;;; manipulate. In the future S-expression will contain just what is needed
;;; to connect to external servers like GitHub.
;;;
;;; The import action will only add the minimum information of the
;;; repository to the database. This is also important for future.
;;;
;;; The serve action is composed of different tasks:
;;; - serve the web pages which are rendered from the query to the database;
;;; - periodically fetch the repositories and import latest commits.
;;;
;;; Other action will allow to set and get the configuration, for example
;;; the period of fetching or removing a repository.
;;;
;;; While the query to the database are straightforward, the fetch of the
;;; repository is composed of many steps:
;;;  1. perform `git fetch` on the repository
;;;  2. update branches
;;;  3. fetch latest commits
;;;  4. organize the commits in the database
;;;
;;; There are just one writer at a time that will update the database,
;;; every other task will just read from the file.

;;;; 3. Implementation

;;;; 3.1. Development and debugging notes

;;;; 3.1.1. Running and compiling

;;; make

;;; 3.1.2 Debugging
;;; User (expand <symbol>) to visualize stuff in your <pre> debug page.

;;;; 3.1.3 Name convention

;;; We will keep the name convention of scheme for names as divided by a
;;; dash. The global variables are stated here and are starred before and
;;; after. Those can be set later from the options.

;; Version of the software
(define VERSION "git-overview 0.2 by 1dotd4")
;; Project name, should be able to edit later
(define *project-name* "git-overview")
;; Database path
(define *data-file* "./data.sexp")
;; Selected server port
(define *selected-server-port* 6660)

;;;; 3.2 Data explaination

;;;; Git helpers
(define (sh-basename path)
  ;; Function that takes the basename of a path
  (with-input-from-pipe (format "basename ~A" path)
                        (λ () (read-line))))

(define (make-branch name repo hash)
  (list name repo hash))
(define (branch->name b) (car b))
(define (branch->repo b) (cadr b))
(define (branch->commit b) (caddr b))
(define (branches:find-name-from-hash branches hash)
  (if (null? branches)
    #f
    (if (string=? (branch->commit (car branches)) hash)
      (branch->name (car branches))
      (branches:find-name-from-hash (cdr branches) hash))))

(define (git-branch path name)
  ;; Funciton that takes branches of a repository
  (with-input-from-pipe
    (format "git --no-pager --git-dir=~A branch -r -v --no-abbrev" path)
    (λ ()
       (map
         (λ (line)
            (let
              ((s (string-split line " ")))
              (make-branch
                (car s)
                name
                (cadr s))))
         (read-lines)))))

(define (git-log-dump path)
  ;; Funciton that takes logs of a repository
  (with-input-from-pipe
    (format "git --git-dir=~A --no-pager log --branches --tags --remotes --full-history --date-order --format='format:%H%x09%P%x09%at%x09%an%x09%ae%x09%s%x09%D'"
            path)
    (λ ()
       (map
         (λ (a)
            (string-split a "\t" #t))
         (read-lines)))))


(define (make-commit hash parents repo-name author comment timestamp refs)
  (let ((unixtime (if (string? timestamp)
                    (string->number timestamp)
                    timestamp)))
    (list hash parents repo-name author comment unixtime refs)))

(define (commit->hash c) (car c))
(define (commit->shorthash c) (car (string-chop (commit->hash c) 7)))
(define (commit->parents c) (cadr c))
(define (commit->repository c) (caddr c))
(define (commit->author c) (list-ref c 3))
(define (commit->comment c) (list-ref c 4))
(define (commit->timestamp c) (list-ref c 5))
(define (commit->format-date c) (time->string (seconds->local-time (commit->timestamp c)) "%Y %b %e %a %H:%M:%S %Z"))
(define (commit->refs c) (list-ref c 6))

(define (format-diff current atime)
  ;; Funciton to format how much ago a thing happened
  (let* ((abs-seconds (- current atime))
         (seconds (modulo abs-seconds 60))
         (minutes (quotient abs-seconds 60))
         (hours (quotient minutes 60))
         (days (quotient hours 24))
         (months (quotient days 30)))
    (cond
      ((> months 0) (format "~Amo" months))
      ((> days 0) (format "~Ad" days))
      ((> hours 0) (format "~Ah" hours))
      ((> minutes 0) (format "~Am" minutes))
      (else (format "~As" seconds)))))

(define (commits:less? a b)
  (> (commit->timestamp a)
     (commit->timestamp b)))

(define (commits:get-last commits)
  (car (sort commits commits:less?)))

(define (commits:find-child commit commits)
  (cond ((null? commits) #f)
        ((and (string=? (commit->repository commit) (commit->repository (car commits)))
              (fold binary-or #f (map (lambda (x) (string=? x (commit->hash commit))) (commit->parents (car commits)))))
         (car commits))
        (else (commits:find-child commit (cdr commits)))))

(define (commits:find-ref commit commits)
  (let ((child (commits:find-child commit commits)))
    (if child
      (commits:find-ref child commits)
      (if (string=? "" (commit->refs commit))
        #f
        commit))))

(define (make-user email name)
  (cons email name))

(define (user->email a) (car a))
(define (user->name a) (cdr a))

(define (user:same? a b)
  (string=? (user->email a)
            (user->email b)))
(define (users:get-name-from-email authors email)
  (if (null? authors)
    #f
    (if (string=? email (user->email (car authors)))
      (user->name (car authors))
      (users:get-name-from-email (cdr authors) email))))

(define (commits:filter-by-user-emails user-emails commits)
  (filter
    (λ (commit) 
       (fold binary-or
             #f 
             (map
               (λ (email)
                  (string=? email
                            (commit->author commit)))
               user-emails)))
    commits))

(define (commits:filter-by-repository-name repo-names commits)
  (filter
    (λ (commit) 
       (fold binary-or
             #f 
             (map
               (λ (a-repo-name)
                  (string=? a-repo-name
                            (commit->repository commit)))
               repo-names)))
    commits))

(define (query:collect type query)
  (flatten
    (map
      (λ (param)
         (if (eq? type (car param))
           (cdr param)
           '()))
      query)))
(define (query:page-number query)
  (let ((query-page-number (query:collect 'page query)))
    (if (null? query-page-number) 1 (string->number (car query-page-number)))))

(define (query:filter-by-users query commits)
  (let ((emails (query:collect 'people query)))
    (if (null? emails)
      commits
      (commits:filter-by-user-emails emails commits))))

(define (query:filter-by-repository query commits)
  (let ((repos (query:collect 'repo query)))
    (if (null? repos)
      commits
      (commits:filter-by-repository-name repos commits))))

(define (make-database repositories people branches commits)
  (list repositories people branches commits))

(define (database->repositories db) (car db))
(define (database->people db) (cadr db))
(define (database->branches db) (caddr db))
(define (database->commits db) (cadddr db))

(define (database:read) (call-with-input-file *data-file* (λ (i) (read i))))

(define (database:merge a b)
  (make-database
    (append (database->repositories a) (database->repositories b))
    (fold (cons-unique user:same?) (database->people a) (database->people b))
    (append (database->branches a) (database->branches b))
    (append (database->commits a) (database->commits b))))

(define (make-repository name path)
  (cons name path))

(define (repository->name r) (car r))
(define (repository->path r) (cdr r))

(define (check-database)
  ;; We check if the database exists and if not we create it.
  (if (not (file-exists? *data-file*))
    (call-with-output-file
      *data-file*
      (λ (db)
         (begin
           (write '(() ; repositories
                    () ; users
                    () ; branches
                    ()) ; commits
                  db)
           (print "Database created."))))))

;;;; 3.3 Import explaination

(define (import-repository path)
  ;; Function to import a repository from a path.
  ;; Will add only the path as it's the main loop to import the data.
  (let ((db (database:read)))
    (if (not (directory-exists? (format "~A.git" path)))
      (print "Could not find .git directory")
      (let ((basename (sh-basename path))
            (repo-path (format "~A.git" path))
            (repositories (database->repositories db))
            (people (database->people db))
            (branches (database->branches db))
            (commits (database->commits db)))
        (if (fold binary-or #f (map
                                 (λ (r) (string=? (repository->name r)
                                                  basename))
                                 repositories))
          (print "This repository already exists")
          (call-with-output-file
            *data-file*
            (λ (o)
               (begin
                 (write
                   (make-database
                     (cons (make-repository basename repo-path)
                           repositories)
                     people
                     branches
                     commits)
                   o)
                 (print "Successfully imported.")))))))))

(define (populate-repository-information repository)
  (let* ((raw-commits (git-log-dump (repository->path repository)))
         (commits (map 
                    (λ (line)
                       (make-commit
                         (car line)                       ; hash
                         (string-split (list-ref line 1)) ; parents
                         (repository->name repository)    ; repository name
                         (list-ref line 4)                ; author email
                         (list-ref line 5)                ; comment
                         (list-ref line 2)                ; timestamp
                         (list-ref line 6)))              ; refs
                    raw-commits))
         (people (fold
                  (cons-unique user:same?)
                  '()
                  (map
                    (λ (line)
                       (make-user
                         (list-ref line 4)   ; author email
                         (list-ref line 3))) ; author name
                    raw-commits)))
         (branches (git-branch (repository->path repository) (repository->name repository)))
         (partial-database (make-database (list repository)
                                          people
                                          branches
                                          commits)))
    partial-database))

(define (fetch-repository-data)
  ;; Function to populate data for each repository
  (let* ((db (database:read))
        (repositories (database->repositories db))
        (data-for-each-repository (map populate-repository-information repositories))
        (merged-data (fold database:merge '(() () () ()) data-for-each-repository)))
    (call-with-output-file
      *data-file*
      (λ (o)
         (begin
           (write merged-data o)
            (print
              "Imported "
              (length (cadddr merged-data))
              " commits from "
              (length (car merged-data))
              " repositories."))))))

(define (retrieve-last-people-activity)
  ;; Function that query for last people activity
  (let* ((db (database:read))
         (commits (database->commits db))
         (people (database->people db))
         (last-commits (map (λ (user) (commits:get-last (commits:filter-by-user-emails (list (user->email user)) commits)))
                            people))
         (commits-with-branches
           (map
             (λ (c)
                (make-commit
                  (commit->hash c)
                  (commit->parents c)
                  (commit->repository c)
                  (users:get-name-from-email
                    (database->people db)
                    (commit->author c))
                  (commit->comment c)
                  (commit->timestamp c)
                  (branches:find-name-from-hash
                    (database->branches db)
                    (commit->hash (commits:find-ref c commits)))))
             last-commits)))
    (sort commits-with-branches commits:less?)))

(define (activate-checkbox-if-in-query name value query)
  (if (null? query)
    '(class "")
    (if (and (eq? (caar query) name)
             (string=? (cdr (car query)) value))
      '(checked)
      (activate-checkbox-if-in-query name value (cdr query)))))

(define *commits-per-page* 30)

(define (build-page-navigation query commits)
  (let* ((page-number (query:page-number query))
         (total-pages (round (/ (length (sort
                                  (query:filter-by-users
                                    query
                                    (query:filter-by-repository
                                      query
                                      commits))
                                  commits:less?))
         *commits-per-page*)))
         (next-page-commits (take-at-most
                              (drop-first
                                (sort
                                  (query:filter-by-users
                                    query
                                    (query:filter-by-repository
                                      query
                                      commits))
                                  commits:less?)
                                (* *commits-per-page* page-number))
                              *commits-per-page*)))
    `(nav (@ (aria-label "Page of commits"))
          (ul (@ (class "pagination justify-content-end"))
              (li (@ (class "page-item"))
                  (a (@ (class "page-link")
                        (href
                          ,(if (> page-number 1)
                             (uri->string (update-uri (uri-reference "") path: '("." "insight") query: (alist-update 'page (sub1 page-number) query)))
                             "#")))
                     "Previous"))
              (li (@ (class "page-item"))
                  (a (@ (class "page-link")
                        (href "#"))
                     ,(string-append (number->string page-number) " of " (number->string total-pages))))
              (li (@ (class "page-item"))
                  (a (@ (class "page-link")
                        (href
                          ,(if (not (null? next-page-commits))
                             (uri->string (update-uri (uri-reference "") path: '("." "insight") query: (alist-update 'page (add1 page-number) query)))
                             "#")))
                     "Next"))))))

(define (build-table-commits current-time query commits branches authors)
  `(table
     (@ (class "table table-hover table-light"))
     (theader
      (tr
        (th "Author")
        (th "Message")
        (th "Commit ID")
        (th "Branch")
        (th "Repository")
        (th "Date")))
     (tbody
       ,(map
          (λ (commit)
             `(tr
                (@ (class ,(string-append
                             (if (> (length (commit->parents commit)) 1)
                               "text-muted small "
                               "")
                             (if (< (- current-time
                                       (commit->timestamp commit))
                                    3600) ; <1h
                               "table-info"
                               ""))))
                (td ,(users:get-name-from-email authors (commit->author commit)))
                (td ,(commit->comment commit))
                (td ,(commit->shorthash commit))
                (td ,(branches:find-name-from-hash
                       branches
                       (commit->hash (commits:find-ref commit commits))))
                (td ,(commit->repository commit))
                (td (@ (title ,(commit->format-date commit)))
                    ,(format-diff current-time (commit->timestamp commit)))))
          (take-at-most
            (drop-first
              (sort
                (query:filter-by-users
                  query
                  (query:filter-by-repository
                    query
                    commits))
                commits:less?)
              (* (sub1 (query:page-number query)) *commits-per-page*))
            *commits-per-page*)))))

(define (retrieve-last-commits current-time query)
  (let* ((db (database:read)))
    (print (expand query))
    `(div
       (@ (class "container"))
       (form
         (@ (action "./insight")
            (method "get"))
            ;; (class "row my-3"))
         (fieldset
           ;; (@ (class "col-lg-3 my-3 mx-auto"))
           (legend "Filter repository")
           ,(map
              (λ (r)
                 `(div
                    (@ (class "form-check form-check-inline"))
                    (input
                      (@ (type "checkbox")
                         (class "form-check-input")
                         (id ,(car r))
                         (name "repo")
                         (value ,(car r))
                         ,(activate-checkbox-if-in-query
                            'repo
                            (car r)
                            query)))
                    (label
                      (@ (class "form-check-label")
                         (for ,(car r)))
                      ,(car r))))
              (database->repositories db)))
         (fieldset
           ;; (@ (class "col-lg-3 my-3 mx-auto"))
           (legend "Filter people")
           ,(map
              (λ (p)
                 `(div
                    (@ (class "form-check form-check-inline"))
                    (input
                      (@ (type "checkbox")
                         (class "form-check-input")
                         (id ,(car p))
                         (name "people")
                         (value ,(car p))
                         ,(activate-checkbox-if-in-query
                            'people
                            (car p)
                            query)))
                    (label
                      (@ (class "form-check-label")
                         (for ,(car p)))
                      ,(cdr p))))
              (database->people db)))
         (input (@ (type "submit")
                   (name "submit")
                   (value "Apply filter")
                   (class "btn btn-primary"))))
       ,(build-page-navigation query (database->commits db))
       ,(build-table-commits current-time
                             query
                             (database->commits db)
                             (database->branches db)
                             (database->people db)))))


;;;; 3.4 Page rendering

(define (data->sxml-card data current-time)
  `(div (@ (class "col-lg-3 my-3 mx-auto"))
        (div (@ (class "card"))
             (div (@ (class "card-body")
                     (title ,(format "~A" (commit->shorthash data))))
                  (h5 (@ (class "card-title")) ,(commit->author data))
                  (h6 (@ (class "card-subtitle")) ,(format "~A/~A" (commit->repository data) (commit->refs data))))
             (div
               (@ (class "card-footer")
                  (title ,(commit->format-date data)))
               ,(format
                  "Last update ~A ago."
                  (format-diff current-time (commit->timestamp data)))))))

(define (build-people data current-time)
  ;; Function that build a page for displaying last update for each committer
  `(div (@ (class "container"))
        (p (@ (class "text-center text-muted mt-3 small"))
           "Tests a nice team")
        (div (@ (class "row my-3"))
             ,(map (λ (d) (data->sxml-card d current-time)) data))))

(define (activate-nav-button current-page expected)
  (format "nav-link text-~A"
          (if (equal? current-page expected)
            "light active"
            "secondary")))

(define (build-page current-page content)
  ;; Function that build the appropriate page
    `(html
       (head
         (meta (@ (charset "utf-8")))
         (title
           ,(string-append 
              (cond 
                ((equal? current-page 'home) "People")
                ((equal? current-page 'insight) "Insights")
                (else "Page not found"))
              " - "
              *project-name*))
         (meta (@ (name "viewport") (content "width=device-width, initial-scale=1, shrink-to-fit=no")))
         (meta (@ (name "author") (content "1dotd4")))
         (link (@
                 (href "https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css")
                 (rel "stylesheet")
                 (integrity "sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC")
                 (crossorigin "anonymous"))))
       (body
         (div (@ (class "navbar navbar-expand-lg navbar-dark bg-dark static-top mb-3"))
              (div (@ (class "container"))
                   (a (@ (class "navbar-brand") (href "./"))
                      ,(format
                         "Git overview - ~A"
                         *project-name*))
                   (ul (@ (class "nav ml-auto"))
                       (li (@ (class "nav-item"))
                           (a (@ (class ,(activate-nav-button current-page 'home))
                                 (href "./"))
                              "People"))
                       (li (@ (class "nav-item"))
                           (a (@ (class ,(activate-nav-button current-page 'insight))
                                 (href "./insight"))
                              "Insights")))))
         ,content
         (div (@ (class "container text-secondary text-center my-4 small"))
              (a (@ (class "text-info") (href "http://unpx.net/code/git-overview.git/"))
                 ,VERSION))))) ;; - end body -

;;;; 3.5 Webserver
(import spiffy
        intarweb
        uri-common
        sxml-serializer)

(define (send-sxml-response sxml)
  ;; Function to serialize and send SXML as HTML
  (with-headers
    `((connection close))
    (λ () (write-logged-response)))
  (serialize-sxml
    sxml
    output: (response-port (current-response))))

(define (handle-request continue)
  ;; Function that handles an HTTP requsest in spiffy
  (let* ((uri (request-uri (current-request)))
         (path (uri-path uri))
         (current-time (current-seconds))
         (query (uri-query uri)))
    (cond ((equal? path '(/ "bytebot" ""))
           (send-sxml-response
             (build-page 'home
                         (build-people (retrieve-last-people-activity) current-time))))
          ((equal? path '(/ "bytebot" "insight"))
           (send-sxml-response
             (build-page 'insight
                         (retrieve-last-commits current-time query))))
          (else
            (send-sxml-response
              (build-page 'not-found
                          '(div (@ (class "container"))
                                (p (@ (class "text-center text-muted mt-3 small"))
                                   "Page not found."))))))))

;; Map a any vhost to the main handler
(vhost-map `((".*" . ,handle-request)))

;;;; 3.6 Command line implementation
(import args
        (chicken port)
        (chicken process-context))

;; This is used to choose an operation by options
(define (operation) 'none)

(define opts
  ;; List passed to args:parse to choose which option will be selected and validated.
  (list (args:make-option (i import) (required: "REPOPATH") "Import from repository at path REPOPATH"
                          (set! operation 'import))
        (args:make-option (n name) (required: "PROJECTNAME") "Set project name"
                          (set! *project-name* arg))
        (args:make-option (s serve) #:none "Serve the database"
                          (set! operation 'serve))
        (args:make-option (v V version) #:none "Display version"
                          (print VERSION)
                          (exit))
        (args:make-option (h help) #:none "Display this text" (usage))))

(define (usage)
  ;; Function that will show the usage in case 'help is selected or in the
  ;; default case
  (with-output-to-port
    (current-error-port)
    (λ ()
       (print "Usage: " (car (argv)) " [options...] [files...]")
       (newline)
       (print (args:usage opts))
       (print VERSION)))
  (exit 1))

(receive
  ;; This is the main part of the program where it's decided which operation
  ;; will be executed.
  (options operands)
  (args:parse (command-line-arguments) opts)
  (check-database)
  (cond ((equal? operation 'import)
         (print "Will import from `" (alist-ref 'import options) ".git`.")
         (import-repository (alist-ref 'import options)))
        ((equal? operation 'serve)
         (print "Will serve the database for project " *project-name*)
         ;; Fetch data from database
         ;; TODO: this should be a coroutine
         (fetch-repository-data)
         ;; Set server port in spiffy
         (server-port *selected-server-port*)
         (print "The server is starting")
         ;; Start spiffy web server as seen in §3.5
         (start-server))
        (else
          ;; This is to update the database will not be here
          (fetch-repository-data)))) 

