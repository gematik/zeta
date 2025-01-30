# ZETA

Dies ist ein Repository für Zero Trust Komponenten, einschließlich PEP, PDP, PIP, PAP und Clients. Es enthält Quellcode, umfassende Dokumentation, Testfälle und Kubernetes-Manifestdateien für eine nahtlose Bereitstellung. Ideal für Entwickler, die eine robuste Sicherheitsarchitektur in Cloud-nativen Umgebungen suchen.
Die Gesamtheit dieser Lösung wird ZETA (Zero Trust Access) genannt.

## Table of Contents

- [Introduction](#introduction)
- [ZETA Client APIs](#zeta-client-apis)
  - [Service Discovery](#service-discovery)
  - [PEP](#pep)
    - [Resource Server Access](#resource-server-access)
    - [ZETA/ASL](#zetaasl)
  - [PDP](#pdp)
    - [Client Registration](#client-registration)
    - [Authorization](#authorization)
  - [Notification Service](notification-service)
  - [Error Handling](#error-handling)
- [ZETA Services](#zeta-services)
  - [PIP und PAP Service](#pip-und-pap-service)
  - [Telemetrie-Daten Service](#telemetrie-daten-service)

## Introduction

ZETA ist eine Zero Trust Access-Lösung, die auf dem [Google BeyondCorp](https://cloud.google.com/beyondcorp) -Modell basiert. Es besteht aus mehreren Komponenten, die zusammenarbeiten, um eine sichere und nahtlose Zugriffskontrolle für Cloud-native Anwendungen zu ermöglichen. Die Hauptkomponenten sind:

- **ZETA Guard**: Ein PEP und ein PDP, die die Zugriffskontrolle auf Anwendungsebene durchsetzen.
  - **Policy Enforcement Point (PEP)**: Ein Client, der die Zugriffskontrolle auf Anwendungsebene durchsetzt.
  - **Policy Decision Point (PDP)**: Ein Server, der Zugriffsentscheidungen basierend auf Richtlinien trifft.
- **PIP und PAP Service**: Ein Service, der Richtlinieninformationen speichert und verwaltet.
- **ZETA Client**: Client Komponente, die die ZETA Guard-APIs verwendet.


## ZETA Client APIs

Der ZETA-Client ist eine Bibliothek, die von Anwendungen verwendet wird, um die ZETA Guard-APIs aufzurufen. Es enthält die folgenden APIs:

### Service Discovery

Der ZETA-Client verwendet Well-Known nach [RFC8414](https://www.rfc-editor.org/rfc/rfc8414.html) und [OAuth 2.0 Protected Resource Metadata](https://www.ietf.org/archive/id/draft-ietf-oauth-resource-metadata-13.html) um .