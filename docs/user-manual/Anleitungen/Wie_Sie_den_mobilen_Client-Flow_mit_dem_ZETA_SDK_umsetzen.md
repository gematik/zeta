# Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen

Diese Anleitung beschreibt die Client-Seite des mobilen Client-Flows: die
interaktive Anmeldung über einen sektoralen IDP (SekIDP) mit dem ZETA-SDK,
inklusive der E-Mail-Bindung bei der Erstanmeldung. Die Server-Sicht auf
denselben Flow beschreibt
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).

> [!WARNING]
> Der mobile Client-Flow ist ein **Vorschau-Feature**. Serverseitig muss der
> ZETA-Guard mit `ZETA_OIDC_FLOW_ENABLED=true` betrieben werden; die
> Attestierung mobiler Clients ist dort derzeit gemockt.

---

Status: Entwurf (Vorschau-Feature)

Zielgruppe: Primärsystem-Hersteller (FdV-/App-Entwickler)

Stand: ZETA-SDK 2.0.0

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Konfiguration](#konfiguration)
- [Anmeldung starten](#anmeldung-starten)
- [AuthorizationLauncher implementieren](#authorizationlauncher-implementieren)
- [E-Mail-Bindung: OtpCallback implementieren](#e-mail-bindung-otpcallback-implementieren)
- [E-Mail-Adresse ändern](#e-mail-adresse-ändern)
- [Migration von Version 1.3.x](#migration-von-version-13x)
- [Test-Umgebung](#test-umgebung)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Voraussetzungen

- Ein ZETA-Guard mit aktiviertem OIDC-Flow (`ZETA_OIDC_FLOW_ENABLED=true` an
  Keycloak- und Konfigurations-Container) und konfiguriertem SMTP für den
  OTP-Versand (siehe [Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md)).
- Ein erreichbarer SekIDP (für Tests siehe [Test-Umgebung](#test-umgebung)).
- Grundlegende SDK-Integration wie in
  [Wie Sie das ZETA-SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md)
  beschrieben, auf Android inklusive `ZetaInit.initAndroid(...)` (siehe
  [Android und iOS](Wie_Sie_das_ZETA_SDK_integrieren.md#android-und-ios)).
- Zwei Redirect-URIs, die die App empfangen kann, z. B. über ein eigenes
  URL-Schema oder App Links.

## Konfiguration

Statt eines SM-B/SMC-B-`SubjectTokenProvider` wird in der `AuthConfig` ein
`OidcTokenProvider` mit einer `OidcConfig` als `subjectTokenProvider`
übergeben:

```kotlin
val oidcProvider = OidcTokenProvider(
    OidcConfig(
        redirectUri = "de.example.app://app",        // finaler Redirect: Keycloak liefert hier den Authorization Code
        oidcRedirectUri = "de.example.app://oidc",   // Zwischen-Redirect: der SekIDP liefert hier code und state
        idpIss = "https://sekidp.example",           // Issuer des SekIDP (wird als idp_iss im PAR gesendet)
        idpAlias = "zeta-sekidp-oidc",               // Alias des IDP-Brokers im Guard
        authorizationLauncher = myLauncher,          // öffnet den Browser, liefert den finalen Redirect
        otpCallback = myOtpCallback,                 // fragt E-Mail und OTP ab (siehe unten)
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

| Attribut                | Beschreibung                                                                                                                                                       |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `redirectUri`           | Finale Redirect-URI der App, an die Keycloak am Ende der Anmeldung den Authorization Code liefert (**äußerer** Callback, Abschluss beim ZETA-Guard)                 |
| `oidcRedirectUri`       | Zwischen-Redirect-URI, an die der SekIDP `code` und `state` liefert; diese werden an den Broker von Keycloak weitergereicht (**innerer** Callback, Abschluss beim SekIDP) |
| `idpIss`                | Issuer-URL des SekIDP, gegen den sich der Nutzer anmeldet; wird als `idp_iss` im PAR gesendet                                                                      |
| `idpAlias`              | Alias des SekIDP im Keycloak-Broker; daraus ergibt sich der Broker-Endpunkt `{issuer}/broker/{idpAlias}/endpoint`                                                  |
| `authorizationLauncher` | **Pflicht.** Öffnet die Anmeldung im System-Browser und liefert den finalen Redirect an `redirectUri` zurück (siehe unten)                                          |
| `otpCallback`           | Fragt während der E-Mail-Bindung E-Mail-Adresse und Einmal-Code ab (siehe unten)                                                                                   |

**Redirect-URIs:** Das SDK registriert `redirectUri` und `oidcRedirectUri` bei
der Dynamic Client Registration automatisch als `redirect_uris`; zugleich
registriert es den Client mit den Grant-Typen `authorization_code`,
Token Exchange und `refresh_token`. Die App muss beide URIs empfangen können.

Alle weiteren Endpunkte (PAR, Authorization, Broker, bind-email) löst das SDK
nach der Discovery selbst aus dem ermittelten Issuer bzw. den
Discovery-Metadaten auf; die App muss keine Guard-Endpunkte konfigurieren.

## Anmeldung starten

PAR und PKCE übernimmt das SDK vollständig: Beim ersten `authenticate()` bzw.
beim ersten Aufruf über den `ZetaHttpClient` erzeugt es PKCE-Verifier/-Challenge
und `state`, sendet den Pushed Authorization Request (mit `redirect_uri`,
`oidc_redirect_uri`, `idp_iss`, Code-Challenge, Scope, `state` und einer Client
Assertion) und erhält eine `request_uri`. Daraus baut es die Authorization-URL
`{authorization_endpoint}?client_id=…&request_uri=…`.

Den Browser-Schritt übernimmt die App über den `AuthorizationLauncher`. Er
liefert die finale Redirect-URL (äußerer Callback mit `code` und `state`) an
das SDK zurück. Das SDK prüft den `state`, tauscht den Code am Token-Endpunkt
(mit DPoP und einer eigenen Client Assertion) und persistiert die Tokens.

Auf Android und iOS attestiert das SDK den Client dabei hardwarebasiert (siehe
[Attestierung](Wie_Sie_das_ZETA_SDK_integrieren.md#attestierung)). Enthält die
Token-Antwort ein ZETA-Attestierungs-Token, speichert das SDK es für eine
spätere erneute Registrierung.

## AuthorizationLauncher implementieren

```kotlin
fun interface AuthorizationLauncher {
    suspend fun open(request: AuthorizationRequest): String
}

data class AuthorizationRequest(
    val authorizationUrl: String,   // im Browser zu öffnende URL
    val redirectUri: String,        // finaler Redirect; sein Erreichen beendet die Anmeldung
    val oidcRedirectUri: String,    // Zwischen-Redirect mit code und state des SekIDP
    val brokerEndpoint: String,     // Keycloak-Endpunkt, an den code und state weitergegeben werden
)
```

`open(request)` muss zwei Browser-Schritte erledigen:

1. `request.authorizationUrl` öffnen und auf den Redirect an
   `request.oidcRedirectUri` warten. Dieser Redirect trägt `code` und `state`
   des SekIDP bzw. `error` und `error_description`, falls die Anmeldung
   fehlschlug.
2. **Denselben Browser** (mit dessen Session-Cookie) an
   `request.brokerEndpoint` schicken und dabei `code` und `state` als
   Query-Parameter anhängen; dann auf den Redirect an `request.redirectUri`
   warten.

Zurückgegeben wird die vollständige, unveränderte Redirect-URL, die an
`redirectUri` eingegangen ist, inklusive Query (z. B.
`de.example.app://app?code=…&state=…`). Das SDK liest `code`, `state` und
`error` daraus und prüft den `state` selbst.

Fehlerbehandlung:

- Leitet der SekIDP in Schritt 1 mit `error` zurück oder bricht der Nutzer die
  Anmeldung ab, wirft der Launcher eine
  `AuthorizationFailedException(error, description)`.
- Wird die aufrufende Coroutine abgebrochen, schließt bzw. bricht der Launcher
  eine offene Browser-Session ab.

Als Referenz enthält die Demo-App (`zeta-client`) Launcher für alle
Plattformen. Sie sind Teil der Demo-App, nicht der SDK-API; Apps können sie als
Vorlage übernehmen:

| Plattform   | Launcher                                                                                                                                                     | Redirect-URIs der Demo                                    |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| Android     | `CustomTabsAuthorizationLauncher` öffnet beide Schritte in Custom Tabs; die `OidcRedirectActivity` empfängt die Redirects über ein Intent-Filter für das eigene URL-Schema | `de.gematik.zeta://app`, `de.gematik.zeta://oidc`         |
| iOS         | `WebAuthenticationSessionLauncher` nutzt `ASWebAuthenticationSession`; das URL-Schema ist in der `Info.plist` der App eingetragen                              | `de.gematik.zeta://app`, `de.gematik.zeta://oidc`         |
| JVM, macOS  | `LoopbackAuthorizationLauncher` startet einen lokalen HTTP-Server auf einem Loopback-Host, der beide Callback-Pfade bedient; beide URIs müssen Host und Port teilen | `{OIDC_BASE_URI}/app`, `{OIDC_BASE_URI}/oidc`             |

Die Launcher der Demo-App für Android, JVM und macOS warten höchstens
5 Minuten auf einen Callback.

## E-Mail-Bindung: OtpCallback implementieren

Bei der Erstanmeldung eines mobilen Clients wird die Identität an eine
E-Mail-Adresse gebunden (TOFU-Faktor F1). Erkennungsmerkmal ist das Feld
`binding_mode` in der Token-Antwort; das Access-Token ist dann ein reduziertes
Binding-Token ohne Refresh-Token. Bei `binding_mode = collect_email` muss die
Antwort den Scope `zeta:email-binding` tragen, bei `binding_mode = verify_otp`
den Scope `zeta:email-verify`, sonst bricht das SDK ab; außerdem nennt sie ggf.
einen `email_hint`. Das SDK führt die Bindung dann automatisch über den
`OtpCallback` der `OidcConfig` durch:

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

Ablauf im SDK:

1. Bei `binding_mode = collect_email` fragt das SDK die Adresse über
   `awaitEmail()` ab und ruft `POST {issuer}/zeta/identity/bind-email` auf
   (Antwort: `challenge_type = email_otp`, `email_hint`). Bei `verify_otp` ist
   die Adresse bereits bekannt und das OTP wurde schon versendet.
2. OTP-Schleife über `awaitOtp(emailHint, rejected)`:
   - `OtpSubmission.Otp(code)` → `POST …/bind-email/verify`; bei
     `status = bound` endet die Schleife, bei einem abgelehnten Code wird der
     Nutzer mit `rejected = true` erneut gefragt.
   - `OtpSubmission.Resend` → `POST …/bind-email/resend`.
3. Das reduzierte Binding-Token wird per Token Exchange gegen den vollwertigen
   Token-Satz (Access- und Refresh-Token) getauscht und persistiert.

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

`changeEmail()` stellt die Registrierung bei Bedarf sicher und sendet
`POST /zeta/identity/email` über den PEP, mit Access-Token (Scope
`zeta:client-management`) und DPoP-Nachweis. Der Aufruf startet die Änderung
nur und liefert `ChangeEmailResponse.Pending` (Einmalcode an die neue Adresse
verschickt) oder `ChangeEmailResponse.Verified` (Adresse war bereits gebunden).
Abgeschlossen wird die Änderung mit `verifyEmailChange(code)`;
`resendEmailChangeCode()` verschickt den Code erneut. Über dieselbe Schnittstelle
listet `listClients()` die Clients der Identität, `deleteClient(id)` entfernt
einen. Fehler wirft das SDK als Unterklassen von `ClientManagementException`.
Die serverseitigen Details (Benachrichtigung der alten Adresse, Security-Event)
beschreibt
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md#client-management-endpunkte).

## Migration von Version 1.3.x

Mit Version 2.0.0 hat sich die `OidcConfig` inkompatibel geändert:

| Bis 1.3.x                                                              | Ab 2.0.0                                                                  |
|------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `requestUri`; das SDK leitete daraus `{requestUri}/app` und `{requestUri}/oidc` ab | `redirectUri` und `oidcRedirectUri` werden explizit angegeben             |
| optionaler `authenticationCallback`, der `clientId` und `request_uri` erhielt und die Authorization-URL selbst zusammensetzte; die Weiterleitung an den Broker übernahm in der Demo-App ein lokaler HTTP-Server | verpflichtender `AuthorizationLauncher`, der die fertige Authorization-URL vom SDK erhält, beide Browser-Schritte übernimmt und den finalen Redirect zurückgibt |
| `BrowserLauncher` und `SystemBrowserAuthenticator` in der Demo-App     | `CustomTabsAuthorizationLauncher`, `WebAuthenticationSessionLauncher` und `LoopbackAuthorizationLauncher` in der Demo-App |

Hintergrund ist ANFTI2-997: Das SDK ruft den Authorization-Endpunkt jetzt nach
dem PAR-Request auf und behebt damit eine Inkompatibilität im OIDC-Flow
zwischen ZETA-Versionen. Wer bisher `{requestUri}/app` und `{requestUri}/oidc`
nutzte, kann dieselben Werte als `redirectUri` bzw. `oidcRedirectUri` angeben.

## Test-Umgebung

- **MailCatcher** für die OTP-Mails: Das ZETA-Guard-Helm-Chart bringt ein
  `mailcatcher`-Subchart mit (`mailcatcher.enabled`, standardmäßig aus). Die
  Web-UI zeigt die versendeten OTP-Mails an; im lokalen Test-Setup ist sie
  über die Route `/mailcatcher` erreichbar. Der Testdriver liest OTPs für
  automatisierte Tests direkt daraus aus (`MailCatcherOtpClient`).
- **SekIDP-Testkomponente:** Für Tests ohne echten sektoralen IDP bringt das
  Helm-Repository ein `sekidp`-Subchart mit (`sekidp.enabled`, standardmäßig
  aus), das gematiks Referenzimplementierung `gsi-server` samt Federation Master
  `gsi-fedmaster` bereitstellt. Es ist ausdrücklich **nicht für Produktion**
  bestimmt. Der frühere Fake-SekIDP-Realm im Authorization Server
  (`use_fake_sekidp_testrealm`) ist entfallen.
- Ein lokales Cluster-Setup beschreibt
  [Wie Sie den Cluster lokal mit KIND aufsetzen](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md).
- Für automatisierte Tests bietet der Testdriver Endpunkte, um E-Mail-Adresse
  und OTP zu übermitteln; der Android-Testdriver liest das OTP selbsttätig aus
  dem MailCatcher (siehe
  [Wie Sie den Testdriver nutzen](Wie_Sie_den_Testdriver_nutzen.md)).

## Aktueller Stand und Einschränkungen

- **Serverseitige Attestierung gemockt:** Der Guard akzeptiert derzeit jede
  Registrierung mit Redirect-URIs und hinterlegt ein festes Client Statement;
  Details und weitere serverseitige Einschränkungen (fehlendes Rate Limiting
  für die OTP-Prüfung, einfaktorige E-Mail-Änderung, angekündigter Breaking
  Change am Antwortformat) siehe
  [Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).
- Die Launcher der Demo-App sind Referenz-Implementierungen, keine
  unterstützte SDK-API; die produktive Browser-Anbindung liegt in der
  Verantwortung der App.
- Der OIDC-Flow ist nur in der Kotlin-Multiplatform-API verfügbar; die
  C#-, C++- und Java-Anbindungen enthalten ihn derzeit nicht
  (siehe [SDK-Übersicht](../Referenzen/SDK-Uebersicht.md)).
- Das reduzierte Binding-Token ist kurzlebig (300 s, kein Refresh-Token);
  bricht die E-Mail-Bindung ab, muss die Anmeldung neu gestartet werden.
