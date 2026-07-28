-- =====================================================================
-- SQL PROJECT: LIBRARY DATABASE ANALYSIS
-- =====================================================================
-- Order of execution:
--   1. Create database
--   2. Create tables (in FK-safe order)
--   3. Load CSV data (in FK-safe order)
--   4. Run task queries (Q1 - Q7)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS library_db;
USE library_db;

-- =====================================================================
-- STEP 1: CREATE TABLES
-- =====================================================================

-- Table: tbl_publisher
DROP TABLE IF EXISTS tbl_publisher;
CREATE TABLE tbl_publisher (
    publisher_PublisherName    VARCHAR(255) PRIMARY KEY,
    publisher_PublisherAddress TEXT,
    publisher_PublisherPhone   VARCHAR(20)
);

-- Table: tbl_library_branch
DROP TABLE IF EXISTS tbl_library_branch;
CREATE TABLE tbl_library_branch (
    library_branch_BranchID      INT PRIMARY KEY AUTO_INCREMENT,
    library_branch_BranchName    VARCHAR(255),
    library_branch_BranchAddress TEXT
);

-- Table: tbl_borrower
DROP TABLE IF EXISTS tbl_borrower;
CREATE TABLE tbl_borrower (
    borrower_CardNo         INT PRIMARY KEY,
    borrower_BorrowerName   VARCHAR(255),
    borrower_BorrowerAddress TEXT,
    borrower_BorrowerPhone  VARCHAR(20)
);

-- Table: tbl_book  (depends on tbl_publisher)
DROP TABLE IF EXISTS tbl_book;
CREATE TABLE tbl_book (
    book_BookID         INT PRIMARY KEY,
    book_Title          VARCHAR(255),
    book_PublisherName  VARCHAR(255),
    FOREIGN KEY (book_PublisherName) REFERENCES tbl_publisher(publisher_PublisherName)
);

-- Table: tbl_book_authors  (depends on tbl_book)
DROP TABLE IF EXISTS tbl_book_authors;
CREATE TABLE tbl_book_authors (
    book_authors_AuthorID   INT PRIMARY KEY AUTO_INCREMENT,
    book_authors_BookID     INT,
    book_authors_AuthorName VARCHAR(255),
    FOREIGN KEY (book_authors_BookID) REFERENCES tbl_book(book_BookID)
);

-- Table: tbl_book_copies  (depends on tbl_book, tbl_library_branch)
DROP TABLE IF EXISTS tbl_book_copies;
CREATE TABLE tbl_book_copies (
    book_copies_CopiesID      INT PRIMARY KEY AUTO_INCREMENT,
    book_copies_BookID        INT,
    book_copies_BranchID      INT,
    book_copies_No_Of_Copies  INT,
    FOREIGN KEY (book_copies_BookID) REFERENCES tbl_book(book_BookID),
    FOREIGN KEY (book_copies_BranchID) REFERENCES tbl_library_branch(library_branch_BranchID)
);

-- Table: tbl_book_loans  (depends on tbl_book, tbl_library_branch, tbl_borrower)
DROP TABLE IF EXISTS tbl_book_loans;
CREATE TABLE tbl_book_loans (
    book_loans_LoansID  INT PRIMARY KEY AUTO_INCREMENT,
    book_loans_BookID   INT,
    book_loans_BranchID INT,
    book_loans_CardNo   INT,
    book_loans_DateOut  DATE,
    book_loans_DueDate  DATE,
    FOREIGN KEY (book_loans_BookID) REFERENCES tbl_book(book_BookID),
    FOREIGN KEY (book_loans_BranchID) REFERENCES tbl_library_branch(library_branch_BranchID),
    FOREIGN KEY (book_loans_CardNo) REFERENCES tbl_borrower(borrower_CardNo)
);

-- =====================================================================
-- STEP 2: LOAD DATA
-- Load order matters because of foreign keys.
-- Adjust the file path below to wherever your CSVs live locally,
-- and make sure 'local_infile' is enabled on your MySQL client/server,
-- OR use MySQL Workbench's "Table Data Import Wizard" instead
-- (right-click table -> Table Data Import Wizard) which handles this
-- without needing LOAD DATA LOCAL INFILE permissions.
-- =====================================================================

-- 1. Publishers
LOAD DATA LOCAL INFILE 'publisher.csv'
INTO TABLE tbl_publisher
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(publisher_PublisherName, publisher_PublisherAddress, publisher_PublisherPhone);

-- 2. Library branches (no BranchID in CSV -> AUTO_INCREMENT assigns it in file order:
--    1=Sharpstown, 2=Central, 3=Saline, 4=Ann Arbor)
LOAD DATA LOCAL INFILE 'library_branch.csv'
INTO TABLE tbl_library_branch
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(library_branch_BranchName, library_branch_BranchAddress);

-- 3. Borrowers
LOAD DATA LOCAL INFILE 'borrower.csv'
INTO TABLE tbl_borrower
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(borrower_CardNo, borrower_BorrowerName, borrower_BorrowerAddress, borrower_BorrowerPhone);

-- 4. Books
LOAD DATA LOCAL INFILE 'books.csv'
INTO TABLE tbl_book
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(book_BookID, book_Title, book_PublisherName);

-- 5. Book authors
LOAD DATA LOCAL INFILE 'authors.csv'
INTO TABLE tbl_book_authors
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(book_authors_BookID, book_authors_AuthorName);

-- 6. Book copies
LOAD DATA LOCAL INFILE 'book_copies.csv'
INTO TABLE tbl_book_copies
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(book_copies_BookID, book_copies_BranchID, book_copies_No_Of_Copies);

-- 7. Book loans (dates come in as M/D/YY text -> convert with STR_TO_DATE)
LOAD DATA LOCAL INFILE 'book_loans.csv'
INTO TABLE tbl_book_loans
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(book_loans_BookID, book_loans_BranchID, book_loans_CardNo, @DateOut, @DueDate)
SET
    book_loans_DateOut = STR_TO_DATE(@DateOut, '%m/%d/%y'),
    book_loans_DueDate  = STR_TO_DATE(@DueDate, '%m/%d/%y');

-- =====================================================================
-- STEP 3: TASK QUERIES
-- =====================================================================

-- Q1: How many copies of "The Lost Tribe" are owned by "Sharpstown"?
SELECT bc.book_copies_No_Of_Copies AS copies_at_sharpstown
FROM tbl_book_copies bc
JOIN tbl_book b          ON bc.book_copies_BookID = b.book_BookID
JOIN tbl_library_branch lb ON bc.book_copies_BranchID = lb.library_branch_BranchID
WHERE b.book_Title = 'The Lost Tribe'
  AND lb.library_branch_BranchName = 'Sharpstown';

-- Q2: How many copies of "The Lost Tribe" are owned by EACH library branch?
SELECT lb.library_branch_BranchName, bc.book_copies_No_Of_Copies
FROM tbl_book_copies bc
JOIN tbl_book b          ON bc.book_copies_BookID = b.book_BookID
JOIN tbl_library_branch lb ON bc.book_copies_BranchID = lb.library_branch_BranchID
WHERE b.book_Title = 'The Lost Tribe';

-- Q3: Names of all borrowers who do NOT have any books checked out.
SELECT borrower_BorrowerName
FROM tbl_borrower
WHERE borrower_CardNo NOT IN (
    SELECT book_loans_CardNo FROM tbl_book_loans WHERE book_loans_CardNo IS NOT NULL
);

-- Q4: Books loaned from "Sharpstown" with DueDate = 2/3/18
--     -> book title, borrower's name, borrower's address
SELECT b.book_Title, br.borrower_BorrowerName, br.borrower_BorrowerAddress
FROM tbl_book_loans bl
JOIN tbl_book b            ON bl.book_loans_BookID = b.book_BookID
JOIN tbl_borrower br       ON bl.book_loans_CardNo = br.borrower_CardNo
JOIN tbl_library_branch lb ON bl.book_loans_BranchID = lb.library_branch_BranchID
WHERE lb.library_branch_BranchName = 'Sharpstown'
  AND bl.book_loans_DueDate = '2018-02-03';

-- Q5: For each library branch, the branch name and total number of books loaned out.
SELECT lb.library_branch_BranchName, COUNT(*) AS total_books_loaned
FROM tbl_book_loans bl
JOIN tbl_library_branch lb ON bl.book_loans_BranchID = lb.library_branch_BranchID
GROUP BY lb.library_branch_BranchName;

-- Q6: Borrowers with more than 5 books checked out
--     -> name, address, number of books checked out
SELECT br.borrower_BorrowerName, br.borrower_BorrowerAddress, COUNT(*) AS books_checked_out
FROM tbl_book_loans bl
JOIN tbl_borrower br ON bl.book_loans_CardNo = br.borrower_CardNo
GROUP BY br.borrower_CardNo, br.borrower_BorrowerName, br.borrower_BorrowerAddress
HAVING COUNT(*) > 5;

-- Q7: For each book authored by "Stephen King", title and number of copies at "Central"
SELECT b.book_Title, bc.book_copies_No_Of_Copies
FROM tbl_book b
JOIN tbl_book_authors ba   ON b.book_BookID = ba.book_authors_BookID
JOIN tbl_book_copies bc    ON b.book_BookID = bc.book_copies_BookID
JOIN tbl_library_branch lb ON bc.book_copies_BranchID = lb.library_branch_BranchID
WHERE ba.book_authors_AuthorName = 'Stephen King'
  AND lb.library_branch_BranchName = 'Central';
