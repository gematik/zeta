# 5.5 Client Management (Neufassung – Entwurf)

## Vorbemerkung

Diese Neufassung ersetzt das bisherige Kapitel 5.5 der Spezifikation Zero Trust Access (ZETA), Version 2.0.1_CC, auf Basis einer Analyse der bestehenden Anforderungen (Afos). Sie verfolgt vier Ziele:

1. **Atomarität**: Jede Anforderung enthält genau eine MUSS-, SOLL- oder DARF-NICHT-Aussage und entspricht damit einem einzelnen, durch Gutachter oder Tester durchführbaren Prüfschritt.
2. **Unabhängigkeit**: Anforderungen referenzieren keine anderen Anforderungen dieses Kapitels. Benötigte Begriffe, Akteure und Zustände werden einmalig in Abschnitt 5.5.0 definiert und dort für alle Folgeabschnitte verbindlich festgelegt. Verweise auf externe Schema-/Annex-Dateien bleiben bestehen, da sie keine Abhängigkeit zwischen zwei Prüfschritten erzeugen.
3. **Klare Gliederung**: Jedes Unterkapitel beginnt mit einer kurzen, nicht-normativen Einleitung, die den Kontext herstellt, bevor die Anforderungen folgen.
4. **Entwicklungsanleitung**: Wo die Ursprungsformulierung technische Realisierungsdetails offenließ (z. B. Zustandsmodell, Vertrauensniveau-Prüfung, Übergangsfristen), wurden diese Lücken geschlossen, damit die Anforderung ohne Rückgriff auf weitere Dokumente umsetzbar ist.

**Nummerierung**: Anforderungs-IDs sind an die Original-Spezifikation angelehnt (Basis-ID der Ursprungsanforderung, ergänzt um `-01`, `-02` usw. bei Aufteilung in mehrere Prüfschritte). Neu ergänzte Anforderungen, für die es keine Ursprungs-ID gibt, sind mit **(neu)** gekennzeichnet. Die verbindliche Vergabe endgültiger Afo-Nummern obliegt der gematik.

**Kritische Überarbeitung (Minimalversion)**: Nach einer sicherheitstechnischen Prüfung wurden alle Anforderungen entfernt, die keinen eigenständigen Sicherheitsbeitrag leisten (reine Client-UX, redundante Klarstellungen, ableitbare Folgesätze) sowie das gesamte Fast-Path-Verfahren (vormals 5.5.5), da es die Angriffsfläche gegenüber der einfachen OTP-Registrierung signifikant vergrößert, ohne für den sicheren Betrieb erforderlich zu sein. Alle gestrichenen Anforderungen sind mit Begründung in Abschnitt 5.5.9 aufgeführt.

**Zweite Prüfstufe (Wortlaut-Redundanz)**: Zusätzlich wurde jedes MUSS/DARF-NICHT-Paar daraufhin geprüft, ob die DARF-NICHT-Aussage lediglich die logische Umkehrung einer bereits mit einem Exklusivitätswort ("ausschließlich", "genau", "erst") formulierten MUSS-Aussage ist und daher keinen eigenen Prüfschritt darstellt. Solche Paare wurden zu einer einzigen Anforderung zusammengeführt; eine wortgleich in zwei Kapiteln vorkommende Anforderung wurde einmal gestrichen. Details siehe Abschnitt 5.5.9.

---

## 5.5.0 Begriffe, Akteure und Zustandsmodell

*Dieser Abschnitt ist nicht normativ. Er definiert die Begriffe, auf die sich die Anforderungen in 5.5.1–5.5.8 stützen, damit diese ohne gegenseitige Verweise auskommen.*

### Akteure

| Akteur | Rolle |
|---|---|
| ZETA Client | Software auf dem Endgerät des Nutzers; initiiert alle Registrierungs- und Verwaltungsoperationen. |
| Authorization Server | Komponente des ZETA Guard; verwaltet Registrierungen, prüft Faktoren, stellt Token aus. |
| Sektoraler IDP | Stellt ausschließlich die Nutzerauthentisierung fest. Er bindet und ersetzt keinen Faktor und autorisiert für sich allein keine Verwaltungsoperation. |
| Notification Service | Komponente des ZETA Guard; versendet Benachrichtigungen an den Nutzer über gebundene Kanäle (E-Mail, Push). |
| Operator | Mensch mit privilegiertem Zugriff auf den administrativen Notfallpfad (Abschnitt 5.5.8). |

### Faktoren

- **F1 (verifizierte E-Mail)**: Auf Identitätsebene geführter Nachweis. Wird bei Erstnutzung nach dem Prinzip Trust-On-First-Use (TOFU) einmalig gepinnt.
- **F2 (Instanzschlüssel)**: Je Client-Instanz gebundenes asymmetrisches Schlüsselpaar. Der private Schlüssel verbleibt ausschließlich auf dem Client.

### TOFU-Datensatz

Jeder Fachdienst (ZETA Guard) führt für jede TI-Identität (KVNR oder Telematik-ID) einen **eigenständigen, fachdienstlokalen TOFU-Datensatz**. Dieser enthält:

- auf **Identitätsebene**: die gebundene, verifizierte E-Mail-Adresse (F1),
- auf **Client-Ebene**, je registrierter Client-Instanz: den Instanzschlüssel (F2) und die berechtigten Audiences.

Der TOFU-Datensatz wird nicht mit anderen Fachdiensten geteilt, auch nicht für dieselbe TI-Identität. Die gebundene E-Mail-Adresse kann daher zwischen Fachdiensten divergieren.

### Zustandsmodell

Jede Client-Registrierung befindet sich zu jedem Zeitpunkt in genau einem der folgenden Zustände.

**Identitätsgebundene (mobile) Clients:**

| Zustand | Bedeutung |
|---|---|
| `pending_user_binding` | F2 attestiert; TI-Identität und F1 noch nicht gebunden. Ausschließlich die Identitätsbindung ist zulässig; kein Ressourcenzugriff. |
| `bound` | F2, TI-Identität und F1 vollständig gebunden. Voller Berechtigungsumfang. |
| `pending_deletion` | Eine Löschung (Abschnitt 5.5.7 oder 5.5.8) ist geplant; die Einspruchsfrist läuft. Ressourcenzugriff wie `bound`; keine weiteren Verwaltungsoperationen zulässig. |
| `tombstone_locked` | Nach Ausführung einer außerordentlichen Löschung. Identität gesperrt; keine Erstnutzung möglich. |
| `tombstone_unlocked` | Nach zweiter, unabhängiger Bestätigung der Wiederregistrierung. Erstnutzung der Identität wieder möglich. |

**Stationäre und identitätslose Clients:**

| Zustand | Bedeutung |
|---|---|
| `registered` | Attestierung/F2 vorhanden; TPM ggf. noch nicht aktiviert. |
| `active` | Nach erstem erfolgreichem Token Exchange mit positiver Policy-Entscheidung. |

### Interaktionsmuster

Jede faktorgebundene Operation folgt demselben Muster: Der Client stellt eine Anfrage; der Authorization Server prüft den Nachweis mindestens eines gebundenen Faktors aus {F1, F2} sowie ggf. die Nutzerauthentisierung; er vollzieht bei Erfolg den Statusübergang und löst bei sicherheitsrelevanten Änderungen eine Benachrichtigung über den Notification Service aus.

---

## 5.5.1 Registrierungsdatenformate

Die Client-Registrierung nutzt drei Datenstrukturen (Client Assertion JWT, Client Statement, Posture-Informationen), die vom Client erzeugt, signiert und dem Authorization Server übermittelt werden. Die verbindlichen Feldlisten und Prüfpflichten sind Teil der Registrierungsschnittstelle (Kapitel 5.3/5.4) und der referenzierten Schema-Dateien (`client-assertion-jwt.yaml`, `client-statement.yaml`, `posture*.yaml`); sie werden hier nicht dupliziert (vgl. Abschnitt 5.5.9).

---

## 5.5.2 Trust-Datensatz und Fachdienstgrenzen

Dieser Abschnitt regelt, wie ein Fachdienst den TOFU-Datensatz einer Identität führt, gegen wen er ihn abgrenzt und wie die Identitätsbindung zustande kommt.

### A_29898 – Eigenständiger, fachdienstlokaler TOFU-Datensatz

**ZETA Guard** MUSS für jede TI-Identität einen TOFU-Datensatz (gebundene E-Mail, Instanzschlüssel, Tombstone- und Einspruchsfrist-Zustände) ausschließlich fachdienstlokal führen, ohne ihn mit einem anderen ZETA Guard zu teilen oder von einem anderen ZETA Guard zu beziehen.

### A_29899 – Keine fachdienstübergreifende Korrelation

**ZETA Guard** DARF NICHT Identitätsdatensätze fachdienstübergreifend verknüpfen oder zur Korrelation eines Nutzers über mehrere Fachdienste hinweg verwenden.

### A_29893 – Geltungsbereich des TOFU-Faktormodells

**Authorization Server** MUSS das Faktormodell (F1, F2) dieses Kapitels ausschließlich auf mobile Client-Registrierungen anwenden, die im TOFU-Verfahren an eine TI-Identität gebunden werden. Für stationäre Clients mit Authentisierung per SMC-B-Token-Exchange sowie für Clients ohne Nutzer-Identität gelten die faktorgebundenen Anforderungen dieses Kapitels nicht.

### A_29894 – Identitätslose Clients: Absicherung ausschließlich über F2 und Posture

**Authorization Server** MUSS einen ohne TI-Identität registrierten Client ausschließlich über den Instanzschlüssel (F2, Proof-of-Possession via JWT-Bearer Assertion) und die plattformabhängige Attestierung absichern, ohne eine identitätsgebundene E-Mail (F1) zu erzeugen oder zu verlangen.

### A_29895 – Identitätslose Clients: Schlüssel-Rollover zulässig

**Authorization Server** MUSS den Schlüssel-Rollover (Abschnitt 5.5.6) auch für identitätslose Clients zulassen, da dieser nur den Besitz des bisherigen Instanzschlüssels voraussetzt.

### A_29895-01 – Identitätslose Clients: kein Recovery-Pfad

Bei Verlust des Instanzschlüssels eines identitätslosen Clients MUSS sich der Client neu registrieren; ein Recovery-Pfad existiert nicht.

### A_29896 – IDP-Authentisierung allein nicht hinreichend

**Authorization Server** MUSS sicherstellen, dass eine erfolgreiche Authentisierung des Nutzers gegenüber dem sektoralen IDP allein nicht ausreicht, um eine bestehende Client-Registrierung zu übernehmen, zu verändern oder wiederherzustellen. Jede solche Operation MUSS zusätzlich den Besitz bzw. die Kontrolle mindestens eines bei der Erstnutzung gebundenen Faktors aus {F1, F2} nachweisen.

### A_29900 – Bindung an die TI-Identität als Ankerpunkt

**Authorization Server** MUSS die TI-Identität (KVNR oder Telematik-ID) als Ankerpunkt des TOFU-Datensatzes führen, an den F1 auf Identitätsebene gebunden wird.

### A_29901 – Trennung von Identitäts- und Client-Ebene

**Authorization Server** MUSS die gebundene E-Mail (F1) auf Identitätsebene sowie den Instanzschlüssel (F2) und die berechtigten Audiences je Client-Instanz auf Client-Ebene führen.

### A_29902 – Verwaltung nur durch eingebuchten Client

**Authorization Server** MUSS für identitäts- und clientbezogene Verwaltungsoperationen (Änderung der E-Mail, Schlüssel-Rollover, Umbenennung und Löschung von Clients) den Nachweis eines an diesem Fachdienst eingebuchten, gültigen Clients verlangen.

### A_29903 – Ableitung der Identitätsbindung aus der Nutzerauthentisierung

**Authorization Server** MUSS die Bindung einer Registrierung an die TI-Identität aus der OIDC-Nutzerauthentisierung ableiten.

### A_29903-01 – Kein realmweites Token als Identitätsnachweis

**Authorization Server** DARF NICHT ein realm-/mandantenweites Initial Access Token ohne Identitätsbezug als hinreichend für die Bindung der Identität werten.

### A_30086 – Einhaltung des Zustandsmodells

**Authorization Server** MUSS jede Client-Registrierung in genau einem der in Abschnitt 5.5.0 definierten Zustände führen und die dort beschriebenen Übergänge einhalten.

### A_30086-01 – Keine Berechtigungsfreigabe im Zustand pending_user_binding

**Authorization Server** DARF im Zustand `pending_user_binding` ausschließlich die Identitätsbindung zulassen.

### A_30086-02 – Tombstone nur für identitätsgebundene Registrierungen

**Authorization Server** MUSS die Zustände `tombstone_locked` und `tombstone_unlocked` ausschließlich auf identitätsgebundene Registrierungen anwenden.

### A_30086-03 – Verwerfung unvollständiger Registrierungen

**Authorization Server** MUSS Registrierungen, die im Zustand `pending_user_binding` bzw. `registered` verbleiben und nicht fristgerecht in den Zustand `bound` bzw. `active` übergehen, nach einer konfigurierbaren Frist verwerfen.

---

## 5.5.3 Erstregistrierung

Bei der Erstregistrierung (First Use) wird eine TI-Identität erstmals an einem Fachdienst mit einer E-Mail-Adresse (F1) und einem Instanzschlüssel (F2) verankert.

### A_29905 – Keine Freischaltung vor E-Mail-Verifikation

**Authorization Server** DARF NICHT den vollen Berechtigungsumfang (Scope/Audiences) freigeben, bevor die E-Mail-Verifikation erfolgreich abgeschlossen ist.

### A_29907 – Instanzschlüssel bleibt beim Client

**Authorization Server** MUSS den Instanzschlüssel (F2) als öffentlichen Schlüssel der Client-Instanz führen. Der zugehörige private Schlüssel DARF NICHT an den Authorization Server übertragen werden.

### A_30085 – E-Mail-Bindung nach OIDC über dedizierte Endpunkte

**Authorization Server** MUSS die E-Mail-Verifikation (F1) nach der OIDC-Nutzerauthentisierung als eigenständigen, identitätsgebundenen Schritt über dedizierte Endpunkte (`bind-email`, `bind-email/verify`) ausführen, getrennt von der späteren E-Mail-Änderung (Abschnitt 5.5.4).

### A_30085-01 – Kein OTP-Versand im Rahmen der Basis-Registrierung

**Authorization Server** DARF NICHT im Rahmen der Basis-Registrierung (`POST /register`) einen E-Mail-OTP-Versand auslösen.

### A_30085-02 – Serverseitige Adresswahl bei bekannter Identität

Bei Folgeregistrierung einer bereits bekannten Identität MUSS **Authorization Server** das OTP ausschließlich an die gespeicherte gebundene Adresse senden. Eine vom Client gelieferte Adresse DARF NICHT verwendet werden.

### A_30085-03 – Autorisierung der Bindeaufrufe über zweckgebundenes Access Token

**Authorization Server** MUSS die Bindeaufrufe über ein DPoP-gebundenes Access Token mit dem Scope `zeta:email-binding` autorisieren. Ein Registration Access Token DARF NICHT vorausgesetzt werden.

### A_30085-04 – Eingeschränkter Token-Scope während der Bindung

**Authorization Server** MUSS im Zustand `pending_user_binding` beim Authorization-Code-Grant ein Access Token ausstellen, das ausschließlich den Scope `zeta:email-binding` trägt, eine Gültigkeit von höchstens 15 Minuten hat und ohne Refresh Token ausgegeben wird.

### A_30085-05 – Vollwertige Token nur nach Abschluss der Bindung

**Authorization Server** MUSS vollwertige Access- und Refresh-Token ausschließlich über einen Token Exchange nach Erreichen des Zustands `bound` ausstellen.

### A_30085-06 – Verwerfung unvollständiger Bindungen

**Authorization Server** MUSS nicht abgeschlossene Registrierungen im Zustand `pending_user_binding` nach einer konfigurierbaren Frist verwerfen.

---

## 5.5.4 Folgeregistrierung und E-Mail-Verwaltung

Dieser Abschnitt regelt das Hinzufügen weiterer Clients zu einer bereits bekannten Identität sowie die spätere Änderung der gebundenen E-Mail-Adresse.

### A_29909 – Eine verifizierte E-Mail je Identität

**Authorization Server** MUSS einer Identität zu jedem Zeitpunkt genau eine verifizierte E-Mail-Adresse zuordnen, die bei der Erstnutzung gebunden wird; das Hinzufügen einer weiteren E-Mail-Adresse ist ausgeschlossen.

### A_30005 – Metadatenaktualisierung ausschließlich zur Umbenennung

**Authorization Server** MUSS die Metadatenaktualisierung über die Registrierungsverwaltung (Content-Type `application/json`) ausschließlich zur Umbenennung des Clients (`client_name`) zulassen und jede Änderung des Instanzschlüssels, der gebundenen E-Mail, der berechtigten Audiences oder der Registrierungsparameter (`jwks`, `redirect_uris`, `grant_types`) ablehnen.

### A_29910 – Erneute E-Mail-Verifikation bei Folgeregistrierung

**Authorization Server** MUSS bei jeder weiteren Registrierung einer bereits bekannten Identität die gebundene E-Mail-Adresse erneut verifizieren.

### A_29910-01 – Keine abweichende E-Mail bei Folgeregistrierung

**Authorization Server** DARF NICHT bei einer Folgeregistrierung eine von der gebundenen E-Mail-Adresse abweichende Adresse zulassen.

### A_29910-02 – Verknüpfung des neuen Clients mit der Identität

**Authorization Server** MUSS den bei einer Folgeregistrierung neu registrierten Client mit dem bestehenden Identitätsdatensatz verknüpfen.

### A_29910-03 – Bindung des Instanzschlüssels des neuen Clients

**Authorization Server** MUSS für den neuen Client dessen eigenen Instanzschlüssel (F2) binden.

### A_29911 – Step-up-Authentisierung bei E-Mail-Änderung

**Authorization Server** MUSS für eine Änderung der gebundenen E-Mail-Adresse eine erneute (Step-up-)Authentisierung des Nutzers gegenüber dem sektoralen IDP verlangen.

### A_29911-01 – Nachweis eines überlebenden Faktors

**Authorization Server** MUSS für eine Änderung der gebundenen E-Mail-Adresse zusätzlich den Nachweis eines überlebenden Faktors verlangen: Besitz des Instanzschlüssels (F2) oder Kontrolle über die bisherige E-Mail-Adresse (F1).

### A_29911-02 – Verifikation der neuen E-Mail-Adresse

**Authorization Server** MUSS die neue E-Mail-Adresse im Rahmen der E-Mail-Änderung verifizieren.

### A_29911-03 – Ablehnung bei fehlender Authentisierung

**Authorization Server** MUSS eine Anfrage zur E-Mail-Änderung bei fehlender oder nicht ausreichender Nutzerauthentisierung mit HTTP-Statuscode 401 und einem Hinweis auf das erforderliche Authentifizierungsniveau ablehnen.

### A_29911-04 (Adressat: ZETA Client) – Durchführung des Step-up-Flows

**ZETA Client** MUSS nach Erhalt der Ablehnung nach A_29911-03 einmalig den regulären Authorization-Code-Flow mit dem geforderten Authentifizierungsniveau durchlaufen.

### A_29911-05 – Prüfung des Step-up-Nachweises

**Authorization Server** MUSS das von ihm selbst ausgestellte, DPoP-gebundene Access Token als Nachweis der Step-up-Authentisierung akzeptieren und dabei dessen Signatur, die aus der Nutzerauthentisierung übernommenen Authentisierungs-Claims, die Aktualität des Authentisierungszeitpunkts sowie die DPoP-Bindung prüfen.

### A_29912 – Identitätsweite Wirkung der E-Mail-Änderung

**Authorization Server** MUSS eine erfolgreiche E-Mail-Änderung identitätsweit für alle Clients dieser Identität an diesem Fachdienst wirksam machen.

---

## 5.5.5 Fachdienstübergreifende Fast-Path-Registrierung (entfällt in der Minimalversion)

Das Fast-Path-Verfahren (Registrierung an einem Fachdienst unter Übernahme von Identitätsbindung und E-Mail aus einem an einem anderen Fachdienst ausgestellten Attestation Token) wurde vollständig gestrichen. Begründung siehe Abschnitt 5.5.9. Die Erstregistrierung erfolgt in der Minimalversion ausschließlich über die E-Mail-OTP-Verfahren aus 5.5.3 und 5.5.4.

---

## 5.5.6 Schlüssel-Rollover

Der Instanzschlüssel (F2) wird regelmäßig gewechselt, ohne dass dabei die Registrierung selbst neu aufgebaut werden muss (In-Place-Rollover).

### A_29921 – Regelmäßiger Schlüsselwechsel mit Proof-of-Possession

**ZETA Client** MUSS seinen Instanzschlüssel regelmäßig wechseln. Der Wechsel MUSS als In-Place-Rollover erfolgen und durch eine Signatur mit dem bisherigen, aktiven Instanzschlüssel autorisiert werden.

### A_29921-01 – Kein Wechsel allein auf Basis eines Verwaltungstokens

**Authorization Server** DARF NICHT einen Schlüsselwechsel allein auf Basis eines Registration Access Token zulassen.

### A_29922 – Äußere Signatur als Autorisierung

**Authorization Server** MUSS für den Rollover eine verschachtelte Signaturstruktur verlangen, deren äußere Signatur mit dem bisherigen Schlüssel erstellt ist und die Autorisierung des Wechsels nachweist.

### A_29922-01 – Innere Signatur als Anti-Substitution

Die verschachtelte Signaturstruktur MUSS zusätzlich eine innere, mit dem neuen Schlüssel erstellte Signatur enthalten, die den Nachweis der Kontrolle über den neuen Schlüssel erbringt.

### A_29923 – Einmal-Nonce gegen Wiedereinspielung

**Authorization Server** MUSS den Rollover an einen serverseitig ausgestellten Einmal-Nonce binden.

### A_29923-01 – Bindung an die Guard-Audience

**Authorization Server** MUSS den Rollover an die Identität des anfragenden Guards (Audience) binden.

### A_29923-02 – Bindung an HTTP-Methode und Ziel-URI

**Authorization Server** MUSS den Rollover an die HTTP-Methode und die Ziel-URI der Anfrage binden.

### A_29924 – Übergangszeitraum ausschließlich für Ressourcenzugriff

**Authorization Server** MUSS nach erfolgreichem Rollover den bisherigen Schlüssel für einen begrenzten Übergangszeitraum ausschließlich für den Ressourcenzugriff weiter akzeptieren und DARF ihn nicht mehr für Verwaltungsoperationen, insbesondere einen erneuten Rollover, akzeptieren.

### A_29924-01 (neu) – Policy-definierte Dauer des Übergangszeitraums

Die Dauer des Übergangszeitraums MUSS über Policy definiert und dokumentiert sein und MUSS mindestens der maximalen Gültigkeitsdauer eines zum Rollover-Zeitpunkt bereits ausgestellten Access Tokens entsprechen.

### A_29925 – Invalidierung des bisherigen Schlüssels

**Authorization Server** MUSS den bisherigen Schlüssel nach Ablauf des Übergangszeitraums vollständig invalidieren und aus dem Schlüsselmaterial des Clients entfernen.

### A_29926 – Keine Kopplung von Rollover und Faktoränderung

**Authorization Server** DARF NICHT einen Schlüssel-Rollover mit einer Änderung von E-Mail (F1) in einer untrennbaren Operation zusammenfassen.

---

## 5.5.7 Geräte- und Client-Verwaltung

Dieser Abschnitt regelt die Verwaltung mehrerer, derselben Identität zugeordneter Clients, insbesondere die Löschung einzelner Geräte.

### A_29934 – Löschung anderer Clients nur auf Client-Ebene

**Authorization Server** MUSS einem eingebuchten Client die Löschung eines anderen Clients derselben Identität erlauben.

### A_29934-01 – Keine Änderung von F1 bei Client-Löschung

**Authorization Server** DARF NICHT bei der Löschung eines Clients den identitätsgebundenen Faktor (F1) verändern oder entfernen.

### A_29935 – Benachrichtigung bei Client-Löschung

**Authorization Server** MUSS bei der Löschung eines Clients die gebundene E-Mail-Adresse der Identität benachrichtigen.

### A_29936 – Erhöhte Anforderung bei Löschung des letzten Clients

**Authorization Server** MUSS für die Löschung des letzten verbleibenden Clients einer Identität eine Step-up-Authentisierung verlangen oder die Löschung mit einer Einspruchsfrist (Veto-Fenster) ausführen.

### A_29937 – Fachdienstbezogener Geltungsbereich der Löschung

**Authorization Server** MUSS Client-Löschungen ausschließlich auf den eigenen Fachdienst beziehen.

### A_29938 – Fortbestand der Identität nach Löschung des letzten Clients

**Authorization Server** MUSS den Identitätsdatensatz nach Löschung des letzten Clients erhalten. Eine erneute Einbuchung MUSS als Folgeregistrierung mit erneuter Verifikation der bestehenden E-Mail behandelt werden.

### A_29939 – Autorisierungsprüfung bei Client-übergreifender Löschung

**Authorization Server** MUSS bei der Löschung eines anderen Clients prüfen, dass der Ziel-Client tatsächlich zur Identität des aufrufenden Clients gehört, und einen nicht zugehörigen Ziel-Client mit HTTP-Statuscode 403 ablehnen.

---

## 5.5.8 Außerordentliche Löschung (Notfallpfad)

Hat ein Nutzer alle online verfügbaren Faktoren (F1, F2) verloren, stellt der Notfallpfad die letzte Möglichkeit dar, die Identität durch einen Operator sperren und später wiederherstellen zu lassen.

### A_29940 – Notfallpfad bei vollständigem Faktorverlust

**Authorization Server** MUSS einen außerordentlichen Löschpfad bereitstellen für den Fall, dass ein Nutzer alle online verfügbaren Faktoren verloren hat und eine Selbst-Recovery nicht mehr möglich ist.

### A_29940-01 – Kein Zugriff durch den Löschprozess selbst

Der Notfall-Löschprozess DARF NICHT Zugriff gewähren, ein Token ausstellen oder einen Faktor neu binden.

### A_29941 – Hochassuranter, IDP-unabhängiger Identitätsnachweis

**Authorization Server** MUSS für die Notfall-Löschung ausschließlich einen vom sektoralen IDP unabhängigen Identitätsnachweis auf hohem Vertrauensniveau akzeptieren.

### A_29942 – Verzögerte Ausführung mit Einspruchsfrist

**Authorization Server** MUSS eine Notfall-Löschung erst nach Ablauf einer vorab angekündigten Einspruchsfrist ausführen.

### A_29942-01 – Benachrichtigung während der Einspruchsfrist

**Authorization Server** MUSS während der Einspruchsfrist alle überlebenden, gebundenen Kanäle benachrichtigen.

### A_29942-02 – Policy-definierte Mindestdauer der Einspruchsfrist

Die Dauer der Einspruchsfrist MUSS über Policy definiert und dokumentiert sein und MUSS mindestens so bemessen sein, dass die Benachrichtigung zugestellt und ein überlebender Faktor rechtzeitig ein Veto einlegen kann.

### A_29943 – Veto ausschließlich durch Proof-of-Possession eines Clients

**Authorization Server** MUSS während der Einspruchsfrist den Abbruch der geplanten Löschung ausschließlich durch den Proof-of-Possession eines noch eingebuchten Clients (F2) zulassen.

### A_29944 – Wirkung der Ausführung: Sperre ohne Zugriff

**Authorization Server** MUSS bei Ausführung der Notfall-Löschung den Identitätsdatensatz in den Zustand `tombstone_locked` überführen und alle zugehörigen Client-Registrierungen entfernen.

### A_29945 – Zweite, unabhängige Bestätigung für Wiederregistrierung

**Authorization Server** MUSS nach Erreichen des Zustands `tombstone_locked` die Erstnutzung der betroffenen Identität sperren und diese Sperre erst mit einer zweiten, unabhängigen Bestätigung durch einen anderen Operator als den der Löschungsausführung aufheben (Zustand `tombstone_unlocked`).

### A_29945-01 – Ereignisgesteuerte Aufhebung der Sperre

Die Sperre nach A_29945 DARF NICHT allein durch Zeitablauf aufgehoben werden; sie bleibt ohne die zweite Bestätigung unbegrenzt bestehen.

### A_29946 – Vier-Augen-Prinzip bei Auslösung der Löschung

**Authorization Server** SOLL die Auslösung einer Notfall-Löschung einem Vier-Augen-Prinzip unterwerfen, bei dem die Freigabe der Löschung durch einen anderen Operator erfolgt als deren Initiierung.

### A_29948 – Revisionssichere Protokollierung

**Authorization Server** MUSS alle sicherheitsrelevanten Lebenszyklus-Ereignisse (Registrierung, Faktorbindung, Rollover, Recovery, Client-Löschung, Notfall-Löschung, Wiederregistrierungs-Bestätigung) revisionssicher protokollieren, jeweils mit Zeitstempel und, bei operatorgetriebenen Aktionen, der Operatoridentität und Begründung.

### A_29949 – Absicherung des Administrationskanals

**ZETA Guard** MUSS den Administrationskanal für Notfall-Operationen über gegenseitige TLS-Authentisierung (mTLS) absichern und für die Operatorauthentisierung eine vom sektoralen IDP unabhängige Identitätsquelle verwenden.

---

## 5.5.9 Gestrichene Anforderungen (Begründung)

Dieser Abschnitt dokumentiert alle Anforderungen, die gegenüber dem ursprünglichen Entwurf (siehe Session-Historie) aus der Minimalversion entfernt wurden, mit Begründung. Keine der Streichungen reduziert eine Sicherheitsgarantie der verbleibenden Anforderungen; jede gestrichene Anforderung ist entweder redundant, aus einer verbleibenden Anforderung ableitbar, reine Client-Komfortfunktion ohne eigenen Sicherheitsbeitrag, oder Teil eines insgesamt gestrichenen Verfahrens mit ungünstigem Sicherheits-Nutzen-Verhältnis.

### Vollständig gestrichenes Verfahren: Fachdienstübergreifende Fast-Path-Registrierung

**Gestrichen**: A_29913, A_29913-01, A_29913-02, A_29913-03, A_29913-04, A_29914, A_29914-01, A_29914-02, A_29915, A_29915-01, A_29915-02, A_29915-03, A_29915-04, A_29915-05, A_29916, A_29916-01, A_29918, A_29918-01, A_29919, A_29919-01, A_29920, A_29920-01, A_29920-02, A_29920-03.

**Begründung**: Das Fast-Path-Verfahren ersetzt die serverseitig unabhängig geprüfte E-Mail-OTP-Verifikation durch die Übernahme eines von einem *anderen* Fachdienst ausgestellten Vertrauensnachweises. Das vergrößert die Angriffsfläche gegenüber der einfachen Erstregistrierung strukturell:

- Es überträgt Vertrauen zwischen Fachdiensten, obwohl A_29898/A_29899 (Kapitel 5.5.2) genau das als Grundprinzip ausschließen; die Ausnahme dafür musste eigens formuliert werden.
- Es erforderte allein zur Absicherung des Verfahrens selbst elf zusätzliche, teils neu identifizierte Anforderungen (Existenzprüfung, Vertrauensniveau-Prüfung, Trennung von Besitznachweis und Schlüsselbindung, eigenständiger Verifikationsstatus-Claim), was auf eine hohe inhärente Komplexität und damit Fehleranfälligkeit hindeutet.
- Es findet ohne Nutzerinteraktion statt (keine Bestätigung, kein Step-up); der einzige Schutzmechanismus ist eine nachträgliche Benachrichtigung, die einen bereits vollzogenen Zugriff nicht verhindert, sondern nur nachträglich meldet.
- Der funktionale Nutzen (schnellere Erstregistrierung an einem weiteren Fachdienst) ist ausschließlich Komfort; die Sicherheitsfunktion der Erstregistrierung ist mit dem OTP-Verfahren (Kapitel 5.5.3) bereits vollständig und einfacher abgedeckt.

**Empfehlung**: Falls das Verfahren aus Produktgründen benötigt wird, ist es als optionale Erweiterung mit vollständigem Satz an Schutzmaßnahmen (inkl. Nutzerbestätigung vor Abschluss) gesondert zu spezifizieren, nicht als Teil der sicherheitstechnischen Kernanforderungen an Client Management.

### Redundante oder ableitbare Anforderungen

| Gestrichen | Begründung |
|---|---|
| A_29893-01 (Schlüssel-Rollover clientübergreifend) | Folgt bereits daraus, dass Abschnitt 5.5.6 keine Einschränkung auf identitätsgebundene Clients enthält; kein eigenständiger Prüfschritt. |
| A_29894-02 (keine identitätsbezogene Notfall-Löschung für identitätslose Clients) | Folgt bereits aus A_29894-01 (kein F1 für identitätslose Clients): Ohne F1 existiert kein identitätsbezogener Datensatz, auf den sich eine identitätsbezogene Notfall-Löschung beziehen könnte. |
| A_29897 (keine Faktoränderung allein aus IDP) | Spezialfall von A_29896 (IDP-Authentisierung allein nicht hinreichend für Übernahme, Änderung oder Wiederherstellung); „Änderung eines Faktors" ist bereits von „verändern" umfasst. |
| A_29892 (Bereitstellung der TOFU-Erweiterungsschnittstellen) | Rein deklarative Meta-Anforderung ohne eigenen Prüfinhalt; jede Einzeloperation (E-Mail-Bindung, Rollover, Löschung, Notfallpfad) fordert ihren Endpunkt bereits implizit über die jeweils eigene Anforderung. |
| A_29936-01 (Sammellöschung als wiederholte Einzel-Löschung) | Reine Implementierungsklarstellung ohne eigenständige Prüfbarkeit; die Schutzwirkung (erhöhte Anforderung beim letzten Client) ist bereits vollständig durch A_29936 abgedeckt, unabhängig vom Auslösungsweg. |
| A_29909-02 (Verwaltungsoperationen nur durch registrierten Client) | Wortgleicher Inhalt wie A_29902 (Kapitel 5.5.2), das dieselbe Bedingung für alle identitäts- und clientbezogenen Verwaltungsoperationen bereits allgemeingültig festlegt. A_29902 wurde um „Umbenennung" ergänzt, um die einzige zusätzliche Angabe aus A_29909-02 aufzunehmen. |
| A_29944-01 (kein Zugriff/keine Faktor-Neubindung bei Ausführung der Notfall-Löschung) | Vollständig deckungsgleich mit A_29940-01, das bereits für den gesamten Notfall-Löschprozess (einschließlich seiner Ausführung) festlegt, dass kein Zugriff gewährt, kein Token ausgestellt und kein Faktor neu gebunden werden darf. |

### Zusammengeführte MUSS/DARF-NICHT-Paare (gleiche Aussage, zwei Formulierungen)

Bei folgenden Anforderungspaaren war die DARF-NICHT-Aussage nach Prüfung ausschließlich die logische Umkehrung einer MUSS-Aussage, die bereits mit einem Exklusivitätswort („ausschließlich", „genau", „erst") formuliert war oder formuliert werden konnte. Beide Aussagen wurden zu einer Anforderung zusammengeführt; kein Prüfinhalt ging dabei verloren.

| Zusammengeführt | Ursprüngliche Paarung | Begründung |
|---|---|---|
| A_29898 | A_29898 (MUSS eigenständig führen) + A_29898-01 (DARF NICHT teilen/beziehen) | „Eigenständig, ausschließlich fachdienstlokal führen" schließt Teilen und Beziehen bereits ein. |
| A_29894 | A_29894 (MUSS ausschließlich über F2/Posture absichern) + A_29894-01 (DARF NICHT F1 verlangen) | „Ausschließlich über F2 und Posture" schließt die Verwendung von F1 bereits aus. |
| A_29909 | A_29909 (MUSS genau eine E-Mail zuordnen) + A_29909-01 (DARF NICHT weitere E-Mail zulassen) | „Genau eine" schließt eine zweite E-Mail-Adresse bereits aus. |
| A_30005 | A_30005 (MUSS ausschließlich auf Umbenennung beschränken) + A_30005-01 (MUSS andere Felder ablehnen) | Die konkrete Feldliste aus A_30005-01 wurde als Testkriterium in A_30005 übernommen; „ausschließlich beschränken" und „andere Felder ablehnen" sind dieselbe Aussage. |
| A_29937 | A_29937 (MUSS ausschließlich auf eigenen Fachdienst beziehen) + zweiter Satz (DARF NICHT fachdienstübergreifend) | „Ausschließlich auf den eigenen Fachdienst" schließt eine fachdienstübergreifende Löschung bereits aus. |
| A_29941 | MUSS hohes Vertrauensniveau verlangen + DARF NICHT niedrigeres Niveau akzeptieren | Durch Ergänzung von „ausschließlich" in der MUSS-Aussage wird die Ablehnung niedrigerer Niveaus zur reinen Wiederholung. |
| A_29942 | MUSS mit Einspruchsfrist planen + DARF NICHT sofort ausführen | „Erst nach Ablauf einer Einspruchsfrist ausführen" drückt beides in einer Aussage aus. |
| A_29943 | A_29943 (MUSS Veto durch F2-PoP zulassen) + A_29943-01 (DARF NICHT Veto allein durch F1) | Durch Ergänzung von „ausschließlich" wird der Ausschluss eines F1-only-Vetos zur reinen Wiederholung. |
| A_29924 | A_29924 (MUSS ausschließlich für Ressourcenzugriff akzeptieren) + A_29924-02 (DARF NICHT für Verwaltungsoperationen akzeptieren) | „Ausschließlich für den Ressourcenzugriff" schließt die Verwendung für Verwaltungsoperationen bereits aus; beide Satzhälften wurden zu einer Anforderung zusammengeführt. |
| A_30086-01 | MUSS ausschließlich Identitätsbindung zulassen + DARF NICHT Scope/Audiences freigeben | „Ausschließlich die Identitätsbindung zulassen" schließt jede Freigabe von Scope/Audiences bereits ein. |
| A_30085-05 | MUSS Token nach Abschluss der Bindung ausstellen + DARF NICHT vor Zustand bound ausstellen | „Nach Erreichen des Zustands bound ausstellen" drückt beides in einer Aussage aus. |

**Bewusst nicht zusammengeführt**: Paare, bei denen MUSS und DARF NICHT unterschiedliche Akteure adressieren (z. B. A_29921 [ZETA Client] und A_29921-01 [Authorization Server]) oder bei denen die DARF-NICHT-Aussage einen nicht offensichtlichen, eigenständig testrelevanten Umgehungsweg benennt (z. B. A_29903-01, A_29945-01), bleiben getrennt, da sie unterschiedliche Prüfgegenstände oder Systeme betreffen.

### Reine Client-Komfortfunktionen ohne eigenen Sicherheitsbeitrag

| Gestrichen | Begründung |
|---|---|
| A_5.5.1-01, A_5.5.1-02, A_5.5.1-03 (Registrierungsdatenformate) | Dopplung der in Kapitel 5.3/5.4 (Dynamic Client Registration) bereits normierten Formate; kein eigenständiger, Client-Management-spezifischer Sicherheitsbeitrag. |
| A_29909-03 (neu) (Client-Funktion zur E-Mail-Änderung) | Die Sicherheitsgarantie (Step-up, überlebender Faktor) ist vollständig serverseitig in A_29911 verankert; ob der Client die Funktion aktiv bewirbt, ist Usability, nicht Sicherheit. |
| A_29933 (empfohlene Reihenfolge bei E-Mail-Verlust) | SOLL-Empfehlung für eine Nutzerführung; die zugrunde liegende Sicherheitsfunktion (E-Mail-Änderung mit überlebendem Faktor) bleibt unabhängig davon vollständig wirksam. |
| A_29937-01, A_29937-02, A_29937-03 (neu) (Multi-Fachdienst-Darstellung im Client) | Transparenz-/Usability-Anforderungen an die Darstellung; die eigentliche Sicherheitsgrenze (fachdienstlokale Löschung) ist bereits serverseitig durch A_29937 vollständig durchgesetzt. |
| A_29920-03 (neu) (fachdienstbezogene Gruppierung von Benachrichtigungen) | Entfällt zusätzlich, da das zugehörige Verfahren (Fast-Path) insgesamt gestrichen wurde. |

### Nicht-erzwingbare Empfehlung ohne Prüfkriterium

| Gestrichen | Begründung |
|---|---|
| A_29947 (Vorrang der Selbst-Recovery) | SOLL-Empfehlung ohne eigenes Prüfkriterium; ein Nutzer mit überlebendem Faktor kann Selbst-Recovery ohnehin direkt nutzen und benötigt den Notfallpfad in diesem Fall nicht. Die Anforderung adressiert ein Prozess-Optimierungsziel (Vermeidung unnötiger Eskalation), keine Sicherheitslücke. |


