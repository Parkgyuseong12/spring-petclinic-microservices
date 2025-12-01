-- Spring PetClinic 초기 데이터베이스 생성 스크립트
-- MySQL 8.0 호환

USE petclinic;

-- UTF-8 설정
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 테이블 자동 생성 설정
-- Hibernate DDL-Auto: validate로 설정되어 있음
-- 따라서 테이블은 자동으로 생성되며, 이 스크립트는 참조용입니다.

-- 샘플 수의사 데이터 (선택사항)
-- 테이블이 이미 존재하고 비어있다고 가정

INSERT IGNORE INTO vets (id, first_name, last_name) VALUES 
(1, 'James', 'Carter'),
(2, 'Helen', 'Leary'),
(3, 'Linda', 'Douglas'),
(4, 'Rafael', 'Ortega'),
(5, 'Henry', 'Stevens');

-- 샘플 전문 분야 데이터
INSERT IGNORE INTO specialties (id, name) VALUES 
(1, 'radiology'),
(2, 'surgery'),
(3, 'dentistry');

-- 수의사-전문 분야 연관
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES 
(2, 1),
(3, 2),
(3, 3),
(4, 2),
(5, 1);
