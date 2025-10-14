CREATE SCHEMA ksiegowosc;

CREATE TABLE ksiegowosc.pracownicy (
    id_pracownika SERIAL PRIMARY KEY,
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    adres VARCHAR(255),
    telefon VARCHAR(15)
);
COMMENT ON TABLE ksiegowosc.pracownicy IS 'Tabela zawierająca dane osobowe pracowników firmy.';


CREATE TABLE ksiegowosc.godziny (
    id_godziny SERIAL PRIMARY KEY,
    data DATE NOT NULL,
    liczba_godzin INT NOT NULL,
    id_pracownika INT NOT NULL,
    FOREIGN KEY (id_pracownika) REFERENCES ksiegowosc.pracownicy (id_pracownika)
);
COMMENT ON TABLE ksiegowosc.godziny IS 'Tabela zawiera dane o godzinach pracy pracowników.';


CREATE TABLE ksiegowosc.pensja (
    id_pensji SERIAL PRIMARY KEY,
    stanowisko VARCHAR(100) NOT NULL,
    kwota NUMERIC(10,2) NOT NULL
);
COMMENT ON TABLE ksiegowosc.pensja IS 'Tabela zawiera dane o wysokości pensji dla każdego stanowiska w firmie.';


CREATE TABLE ksiegowosc.premia (
    id_premii SERIAL PRIMARY KEY,
    rodzaj VARCHAR(255) NOT NULL,
    kwota NUMERIC(10,2) NOT NULL
);
COMMENT ON TABLE ksiegowosc.premia IS 'Tabela zawiera dane o rodzajach i wysokości otrzymanych premii.';


CREATE TABLE ksiegowosc.wynagrodzenie (
    id_wynagrodzenia SERIAL PRIMARY KEY,
    data DATE NOT NULL,
    id_pracownika INT NOT NULL,
    id_godziny INT,
    id_pensji INT,
    id_premii INT,
    FOREIGN KEY (id_pracownika) REFERENCES ksiegowosc.pracownicy (id_pracownika),
    FOREIGN KEY (id_godziny) REFERENCES ksiegowosc.godziny (id_godziny),
    FOREIGN KEY (id_pensji) REFERENCES ksiegowosc.pensja (id_pensji),
    FOREIGN KEY (id_premii) REFERENCES ksiegowosc.premia (id_premii)

);
COMMENT ON TABLE ksiegowosc.wynagrodzenie IS 'Tabela zawiera szczegółowe informacje o wynagrodzeniu każdego pracownika firmy.';

--5a) Wyświetl tylko id pracownika oraz jego nazwisko. 
SELECT id_pracownika, nazwisko
FROM ksiegowosc.pracownicy;

--5b) Wyświetl id pracowników, których płaca jest większa niż 1000. 
SELECT w.id_pracownika
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja p ON w.id_pensji = p.id_pensji
LEFT JOIN ksiegowosc.premia pre ON w.id_premii = pre.id_premii
WHERE (p.kwota + COALESCE(pre.kwota, 0)) > 1000;

--5b DLA SPRAWDZENIA
SELECT w.id_pracownika, p.kwota, p.stanowisko, pre.kwota, pre.rodzaj, (p.kwota + COALESCE(pre.kwota, 0)) AS płaca
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja p ON w.id_pensji = p.id_pensji
JOIN ksiegowosc.pracownicy pr ON w.id_pracownika = pr.id_pracownika
LEFT JOIN ksiegowosc.premia pre ON w.id_premii = pre.id_premii
WHERE (p.kwota + COALESCE(pre.kwota, 0)) > 1000;

--5c) Wyświetl id pracowników nieposiadających premii, których płaca jest większa niż 2000. 
SELECT w.id_pracownika
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja p ON w.id_pensji = p.id_pensji
WHERE w.id_premii IS NULL  AND p.kwota > 2000;

--5c DLA SPRAWDZENIA
SELECT w.id_pracownika, p.kwota, p.stanowisko, pre.kwota
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja p ON w.id_pensji = p.id_pensji
LEFT JOIN ksiegowosc.premia pre ON w.id_premii = pre.id_premii
WHERE w.id_premii IS NULL  AND p.kwota > 2000;

--5d) Wyświetl pracowników, których pierwsza litera imienia zaczyna się na literę ‘J’. 
SELECT p.imie, p.nazwisko
FROM ksiegowosc.pracownicy as p
WHERE p.imie LIKE'J%';

--5e) Wyświetl pracowników, których nazwisko zawiera literę ‘n’ oraz imię kończy się na literę ‘a’. 
SELECT p.imie, p.nazwisko
FROM ksiegowosc.pracownicy as p
WHERE p.imie LIKE'%a' AND p.nazwisko LIKE'%n%';

--5f Wyświetl imię i nazwisko pracowników oraz liczbę ich nadgodzin, przyjmując, iż standardowy czas pracy to 160h miesięcznie.
SELECT 
    pr.imie,
    pr.nazwisko,
    SUM(g.liczba_godzin) AS przepracowane_godziny,
    CASE 
        WHEN SUM(g.liczba_godzin) > 160 THEN SUM(g.liczba_godzin) - 160
        ELSE 0
    END AS nadgodziny
FROM ksiegowosc.pracownicy pr
LEFT JOIN ksiegowosc.godziny g ON pr.id_pracownika = g.id_pracownika
GROUP BY pr.imie, pr.nazwisko;

--5g) Wyświetl imię i nazwisko pracowników, których pensja zawiera się w przedziale 1500 – 3000 PLN. 
SELECT pr.imie, pr.nazwisko, pe.kwota
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w on pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe on w.id_pensji = pe.id_pensji
WHERE pe.kwota BETWEEN 1500 and 3000;

--5h) Wyświetl imię i nazwisko pracowników, którzy pracowali w nadgodzinach i nie otrzymali premii. 
SELECT pr.imie, pr.nazwisko
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.godziny g ON w.id_godziny = g.id_godziny
WHERE w.id_premii IS NULL
GROUP BY pr.imie, pr.nazwisko
HAVING SUM(g.liczba_godzin) > 160;


--5i) Uszereguj pracowników według pensji.
SELECT pr.imie, pr.nazwisko, pe.kwota
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w on pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
ORDER BY pe.kwota DESC

--5j) Uszereguj pracowników według pensji i premii malejąco. 
SELECT pr.imie, pr.nazwisko, pe.kwota, pre.kwota
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w on pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
ORDER BY pe.kwota DESC, pre.kwota DESC

--5k) Zlicz i pogrupuj pracowników według pola ‘stanowisko’. 
SELECT COUNT(*), pe.stanowisko
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
GROUP BY pe.stanowisko

--5l Policz średnią, minimalną i maksymalną płacę dla stanowiska ‘kierownik’
SELECT pe.stanowisko, MAX(pe.kwota + pre.kwota) AS srednia_placa
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
WHERE pe.id_pensji = 6
GROUP BY pe.stanowisko;

SELECT pe.stanowisko, MIN(pe.kwota + pre.kwota) AS srednia_placa
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
WHERE pe.id_pensji = 6
GROUP BY pe.stanowisko;

SELECT pe.stanowisko, AVG(pe.kwota + pre.kwota) AS srednia_placa
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
WHERE pe.id_pensji = 6
GROUP BY pe.stanowisko;

--sprawdzenie
SELECT pe.stanowisko, (pe.kwota + COALESCE(pre.kwota,0)) AS srednia_placa
FROM ksiegowosc.pracownicy pr
JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
WHERE pe.id_pensji = 6;

--5m) Policz sumę wszystkich wynagrodzeń. 
SELECT SUM(pe.kwota + COALESCE(pre.kwota,0))
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii

--5n(f) Policz sumę wynagrodzeń w ramach danego stanowiska. 
SELECT SUM(pe.kwota + COALESCE(pre.kwota,0)), pe.stanowisko as suma_wynagrodzen
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
GROUP BY pe.stanowisko;

--5o(g) Wyznacz liczbę premii przyznanych dla pracowników danego stanowiska. 
SELECT COUNT(pre.id_premii) as liczba_premii, pe.stanowisko
FROM ksiegowosc.wynagrodzenie w
JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
LEFT JOIN ksiegowosc.premia pre on w.id_premii = pre.id_premii
GROUP BY pe.stanowisko;

--5p(h) Usuń wszystkich pracowników mających pensję mniejszą niż 1200 zł.
DELETE FROM ksiegowosc.pracownicy pr
WHERE pr.id_pracownika IN (
    SELECT pr.id_pracownika
    FROM ksiegowosc.pracownicy pr
    JOIN ksiegowosc.wynagrodzenie w ON pr.id_pracownika = w.id_pracownika
    JOIN ksiegowosc.pensja pe ON w.id_pensji = pe.id_pensji
    WHERE pe.kwota < 1200
);
