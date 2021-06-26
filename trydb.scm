;; This document is a playground for sqlite.

(import sqlite3)

(define (get-people-stt) "select * from people;")

;; Test database is:
;; create table people(email varchar(50) primary key, name varchar(50));
;; insert into people values ('foo@here.net', 'foo');
;; insert into people values ('bar@here.net', 'bar');

(let* ((db (open-database "./test.sqlite3"))
        (people (map-row (lambda (x y) `(,x ,y)) db (get-people-stt))))
  (print people))
