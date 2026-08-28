# Wie Sie den mobilen Client-Flow mit dem ZETA SDK umsetzen

Diese Anleitung beschreibt die Client-Seite des mobilen Client-Flows: die
interaktive Anmeldung über einen sektoralen IDP (SekIDP) mit dem ZETA SDK,
inklusive der E-Mail-Bindung bei der Erstanmeldung. Die Server-Sicht auf
denselben Flow beschreibt
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).

> [!WARNING]
> Der mobile Client-Flow ist ein **Vorschau-Feature**. Serverseitig muss der
> ZETA Guard mit `ZETA_OIDC_FLOW_ENABLED=true` betrieben werden; die
> Attestierung mobiler Clients ist dort derzeit gemockt.

---

Status: Entwurf (Vorschau-Feature)

Zielgruppe: Primärsystem-Hersteller (FdV-/App-Entwickler)

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Konfiguration](#konfiguration)
- [Anmeldung starten](#anmeldung-starten)
- [E-Mail-Bindung: OtpCallback implementieren](#e-mail-bindung-otpcallback-implementieren)
- [E-Mail-Adresse ändern](#e-mail-adresse-ändern)
- [Test-Umgebung](#test-umgebung)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Voraussetzungen

- Ein ZETA Guard mit aktiviertem OIDC-Flow (`ZETA_OIDC_FLOW_ENABLED=true` an
  Keycloak- und Konfigurations-Container) und konfiguriertem SMTP für den
  OTP-Versand (siehe [Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md)).
- Ein erreichbarer SekIDP (für Tests: Fake-SekIDP, siehe
  [Test-Umgebung](#test-umgebung)).
- Grundlegende SDK-Integration wie in
  [Wie Sie das ZETA SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md)
  beschrieben.

## Konfiguration

Statt eines SM-B/SMC-B-`SubjectTokenProvider` wird in der `AuthConfig` ein
`OidcTokenProvider` mit einer `OidcConfig` als `subjectTokenProvider`
übergeben:

```kotlin
val oidcProvider = OidcTokenProvider(
    OidcConfig(
        idpIss = "https://sekidp.example",       // Issuer des SekIDP (wird als idp_iss im PAR gesendet)
        idpAlias = "zeta-sekidp-oidc",           // Alias des IDP-Brokers im Guard
        requestUri = "http://127.0.0.1:8765",    // Basis-URI der lokalen Callbacks
        authenticationCallback = myAuthCallback, // öffnet den Browser, liefert den finalen Redirect
        otpCallback = myOtpCallback,             // fragt E-Mail und OTP ab (siehe unten)
    ),
)

val sdk = ZetaSdk.build(
    resource,
    BuildConfig(
        // ... übrige Konfiguration ...
        authConfig = AuthConfig(
            scopes = listOf("zero:audience"),
            exp = 30,
            aslProdEnvironment = false,
            subjectTokenProvider = oidcProvider,
            requiredRoleOid = requiredRoleOid,
        ),
    ),
)
```

**Redirect-URIs:** Aus `requestUri` leitet das SDK zwei Callback-URIs ab, die
bei der Dynamic Client Registration automatisch als `redirect_uris`
registriert werden:

| URI                  | Rolle                                                          |
|----------------------|-----------------------------------------------------------------|
| `{requestUri}/oidc`  | **Innerer** Callback: signalisiert den Abschluss beim SekIDP   |
| `{requestUri}/app`   | **Äußerer** Callback: signalisiert den Abschluss beim ZETA Guard |

Alle weiteren Endpunkte (PAR, Authorization, Broker, bind-email) löst das SDK
nach der Discovery selbst aus dem ermittelten Issuer auf; die App muss keine
Guard-Endpunkte konfigurieren.

## Anmeldung starten

PAR und PKCE übernimmt das SDK vollständig: Beim ersten `authenticate()` bzw.
beim ersten Aufruf über den `ZetaHttpClient` erzeugt es PKCE-Verifier/
-Challenge und `state`, sendet den Pushed Authorization Request (mit
`redirect_uri`, `oidc_redirect_uri`, `idp_iss` und Client Assertion) und
erhält eine `request_uri`.

Den Browser-Schritt liefert die App über den `AuthenticationCallback`: Er
bekommt `clientId` und `request_uri`, öffnet
`{authorization_endpoint}?client_id=…&request_uri=…` im System-Browser und
gibt die finale Redirect-URL (äußerer Callback mit `code` und `state`) an das
SDK zurück. Das SDK prüft den `state`, tauscht den Code am Token-Endpunkt
(mit DPoP und Client Assertion) und persistiert die Tokens.

Als Referenz-Implementierung enthält die Demo-App (`zeta-client`) den
`SystemBrowserAuthenticator` mit dem `BrowserLauncher`: Dieser startet einen
lokalen, eingebetteten HTTP-Server, der beide Callback-Pfade bedient — der
innere Callback (`/oidc`) leitet `code`/`state` per HTTP-Redirect an den
Broker-Endpunkt des Guards weiter (der Browser folgt mit seinem
Session-Cookie), der äußere Callback (`/app`) beendet den Vorgang (Timeout:
5 Minuten). Plattform-Implementierungen des `BrowserLauncher` existieren in
der Demo-App für JVM, macOS, Android (Custom Tabs) und iOS
(`SFSafariViewController`). Der `BrowserLauncher` ist Teil der Demo-App, nicht
der SDK-API — Apps können ihn als Vorlage übernehmen oder einen eigenen
`AuthenticationCallback` implementieren.

## E-Mail-Bindung: OtpCallback implementieren

Bei der Erstanmeldung eines mobilen Clients wird die Identität an eine
E-Mail-Adresse gebunden (TOFU-Faktor F1). Erkennungsmerkmal: Die Token-Antwort
enthält den Scope `zeta:email-verify` und noch kein Refresh Token; die
Antwort nennt außerdem den `binding_mode` (`collect_email` oder `verify_otp`)
und ggf. einen `email_hint`. Das SDK führt die Bindung dann automatisch über
den `OtpCallback` der `OidcConfig`:

```kotlin
interface OtpCallback {
    suspend fun awaitEmail(): String
    suspend fun awaitOtp(emailHint: String?, rejected: Boolean): OtpSubmission
}

sealed class OtpSubmission {
    data class Otp(val code: String) : OtpSubmission()
    data object Resend : OtpSubmission()
}
```

Ablauf im SDK (`completeEmailBinding`):

1. Bei `binding_mode = collect_email` fragt das SDK die Adresse über
   `awaitEmail()` ab und ruft `POST {issuer}/zeta/identity/bind-email` auf
   (Antwort: `challenge_type = email_otp`, `email_hint`). Bei `verify_otp` ist
   die Adresse bereits bekannt und das OTP wurde schon versendet.
2. OTP-Schleife über `awaitOtp(emailHint, rejected)`:
   - `OtpSubmission.Otp(code)` → `POST …/bind-email/verify`; bei
     `status = bound` endet die Schleife, bei einem abgelehnten Code wird der
     Nutzer mit `rejected = true` erneut gefragt.
   - `OtpSubmission.Resend` → `POST …/bind-email/resend`.
3. Das reduzierte Binding-Token wird per Token Exchange gegen den
   vollwertigen Token-Satz (Access + Refresh Token) getauscht und persistiert.

Eine minimale Implementierung, die die UI entkoppelt (angelehnt an den
`TestDriverOtpCallback` im Repository; für eine Compose-UI-Variante siehe
`GuiOtpCallback` in der Demo-App):

```kotlin
class AppOtpCallback : OtpCallback {
    private var pendingEmail: CompletableDeferred<String>? = null
    private var pendingOtp: CompletableDeferred<OtpSubmission>? = null

    override suspend fun awaitEmail(): String {
        val deferred = CompletableDeferred<String>()
        pendingEmail = deferred
        // UI: E-Mail-Eingabemaske anzeigen
        return deferred.await()
    }

    override suspend fun awaitOtp(emailHint: String?, rejected: Boolean): OtpSubmission {
        val deferred = CompletableDeferred<OtpSubmission>()
        pendingOtp = deferred
        // UI: OTP-Eingabe anzeigen; bei rejected == true Fehlerhinweis einblenden
        return deferred.await()
    }

    fun provideEmail(email: String) { pendingEmail?.complete(email) }
    fun provideOtp(code: String) { pendingOtp?.complete(OtpSubmission.Otp(code)) }
    fun requestResend() { pendingOtp?.complete(OtpSubmission.Resend) }
}
```

## E-Mail-Adresse ändern

Ein registrierter, bestätigter Client kann die gebundene Adresse identitätsweit
ändern:

```kotlin
val result: Result<ChangeEmailResponse> = sdk.changeEmail("neu@example.com")
```

`changeEmail()` führt bei Bedarf `discover()` und `register()` aus und sendet
dann `POST {issuer}/zeta/identity/email` mit Body `{"new_email": …}`. Der
Aufruf ist nicht Bearer-Token-autorisiert, sondern über einen mit dem
Instanzschlüssel signierten `Client-Assertion`-Header. Erwartet wird
`202 Accepted` mit einem `status`-Feld; Fehler kommen als RFC-7807 Problem
Details und werden als `ChangeEmailException` geworfen. Die serverseitigen
Details (Benachrichtigung der alten Adresse, Security-Event) beschreibt
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).

## Test-Umgebung

- **MailCatcher** für die OTP-Mails: Das ZETA-Guard-Helm-Chart bringt ein
  `mailcatcher`-Subchart mit (`mailcatcher.enabled`, standardmäßig aus). Die
  Web-UI zeigt die versendeten OTP-Mails an; im lokalen Test-Setup ist sie
  über die Route `/mailcatcher` erreichbar. Der Testdriver liest OTPs für
  automatisierte Tests direkt daraus aus (`MailCatcherOtpClient`).
- **Fake-SekIDP:** Für Tests ohne echten sektoralen IDP kann per
  Terraform-Variable `use_fake_sekidp_testrealm = true` ein einfacher
  Fake-SekIDP-Realm im Authorization Server angelegt werden. Die Variable ist
  ausdrücklich **nicht für Produktion** bestimmt.
- Ein lokales Cluster-Setup beschreibt
  [Wie Sie den Cluster lokal mit KIND aufsetzen](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md).

## Aktueller Stand und Einschränkungen

- **Serverseitige Attestierung gemockt:** Der Guard akzeptiert derzeit jede
  Registrierung mit Redirect-URIs und hinterlegt ein festes Client Statement;
  Details und weitere serverseitige Einschränkungen (fehlendes Rate Limiting
  für die OTP-Prüfung, einfaktorige E-Mail-Änderung, angekündigter Breaking
  Change am Antwortformat) siehe
  [Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).
- Der `BrowserLauncher` und der `SystemBrowserAuthenticator` sind
  Referenz-Implementierungen der Demo-App, keine unterstützte SDK-API; die
  produktive Browser-Anbindung liegt in der Verantwortung der App.
- Der OIDC-Flow ist nur in der Kotlin-Multiplatform-API verfügbar; die
  C#-, C++- und Java-Anbindungen enthalten ihn derzeit nicht
  (siehe [SDK-Übersicht](../Referenzen/SDK-Uebersicht.md)).
- Das reduzierte Binding-Token ist kurzlebig (300 s, kein Refresh Token);
  bricht die E-Mail-Bindung ab, muss die Anmeldung neu gestartet werden.
