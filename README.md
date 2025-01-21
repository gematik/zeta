# ZETA

Dies ist ein Repository für Zero Trust Komponenten, einschließlich PEP, PDP, PIP, PAP und Clients. Es enthält Quellcode, umfassende Dokumentation, Testfälle und Kubernetes-Manifestdateien für eine nahtlose Bereitstellung. Ideal für Entwickler, die eine robuste Sicherheitsarchitektur in Cloud-nativen Umgebungen suchen.
Die Gesamtheit dieser Lösung wird ZETA (Zero Trust Access) genannt.

## Table of Contents

- [Introduction](#introduction)
- [ZETA Client APIs](#zeta-client-apis)
  - [PEP](#pep)
    - [Service Discovery](#service-discovery)
    - [Resource Server Access](#resource-server-access)
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

- ZETA Guard
  - **Policy Enforcement Point (PEP)**: Ein Client, der die Zugriffskontrolle auf Anwendungsebene durchsetzt.
  - **Policy Decision Point (PDP)**: Ein Server, der Zugriffsentscheidungen basierend auf Richtlinien trifft.
- **Policy Information Point (PIP)**: Ein Server, der Richtlinieninformationen für den PDP bereitstellt.
- **Policy Administration Point (PAP)**: Ein Server, der Richtlinienverwaltungsfunktionen bereitstellt.
- **ZETA Client**: Client Komponente, die die ZETA Guard-APIs verwendet.