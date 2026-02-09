<img align="right" width="250" height="47" src="images/Gematik_Logo_Flag.png"/> <br/>

# Zero Trust Access (ZETA) 

Dies ist das Hauptrepository des [Zero Trust Access (ZETA)](https://gemspec.gematik.de/docs/gemSpec/gemSpec_ZETA/latest/)-Projektes. Es enthält Komponentendokumentation, Schnittstellenberschreibungen, Produkthandbuch sowie Links zu Quellcode-Repositories der ZETA-Komponenten.

Die veröffentlichte Version fokussiert auf den stationären Zugang zur TI für Leistungserbringerinstitutionen (LEI).
Beim aktuellen Stand handelt sich um einen funktional vollständigen Stand, bei dem die sicherheitstechnische Prüfung noch nicht abgeschlossen ist. In diesem Kontext fehlt ebenfalls noch eine abschließende Bewertung der Sicherheitsrisiken bei den eingesetzten Drittkomponenten für ZETA SDK und ZETA Guard. Der aktuelle Stand ist nicht für den produktiven Einsatz geeignet, und sollte zusätzlich nur in lokalen Umgebungen für Test- und Integrationszwecke eingesetzt werden.

* [ZETA Dokumentation](https://gematik.github.io/zeta/)
* [Implementierungsleitfaden für Primärsysteme](https://gematik.github.io/zeta/docs/api/v1)
* [ZETA Produkthandbuch](./docs/user-manual/README.md)
* ZETA Guard GitHub-Repositories
    * [Helm Charts](https://github.com/gematik/zeta-guard-helm)
    * [Terraform Ressources](https://github.com/gematik/zeta-guard-terraform)
    * [Policy Decision Point (PDP)](https://github.com/gematik/zeta-guard-keycloak)
    * [Policy Enforcement Point (PEP)](https://github.com/gematik/zeta-guard-ngx-pep)
* [ZETA Client SDK](https://github.com/gematik/zeta-sdk)
* Testunterstützung
    * [ZETA Testfachdienst](https://github.com/gematik/zeta-testfachdienst)
    * [ZETA Tiger Testsuite](https://github.com/gematik/zeta-tiger-testsuite)



## License

(C) EY Strategy and Transactions GmbH, 2025, licensed for gematik GmbH

Apache License, Version 2.0

See the [LICENSE](./LICENSE) for the specific language governing permissions and limitations under the License

## Additional Notes and Disclaimer from gematik GmbH

1. Copyright notice: Each published work result is accompanied by an explicit statement of the license conditions for use. These are regularly typical conditions in connection with open source or free software. Programs described/provided/linked here are free software, unless otherwise stated.
2. Permission notice: Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
   1. The copyright notice (Item 1) and the permission notice (Item 2) shall be included in all copies or substantial portions of the Software.
   2. The software is provided "as is" without warranty of any kind, either express or implied, including, but not limited to, the warranties of fitness for a particular purpose, merchantability, and/or non-infringement. The authors or copyright holders shall not be liable in any manner whatsoever for any damages or other claims arising from, out of or in connection with the software or the use or other dealings with the software, whether in an action of contract, tort, or otherwise.
   3. We take open source license compliance very seriously. We are always striving to achieve compliance at all times and to improve our processes. If you find any issues or have any suggestions or comments, or if you see any other ways in which we can improve, please reach out to: ospo@gematik.de
3. Please note: Parts of this code may have been generated using AI-supported technology. Please take this into account, especially when troubleshooting, for security analyses and possible adjustments.