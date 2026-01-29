# Diplomarbeitsbuch – Backend-Entwicklung SmartDisc App

## Mohana Kovac – Themenschwerpunkt: Backend (mit Frontend-Anteilen)

## Inhaltsverzeichnis

1. [Einleitung und Projektkontext](#1-einleitung-und-projektkontext)
2. [Zielsetzung und Anforderungen](#2-zielsetzung-und-anforderungen)
3. [Technologie-Stack und Architektur](#3-technologie-stack-und-architektur)
4. [Backend-Implementierung](#4-backend-implementierung)
   4.1 [ZIEL-H 17: Authentifizierungssystem (Login/Register)](#41-ziel-h-17-authentifizierungssystem-loginregister)
   4.2 [ZIEL-H 19: Dashboard- und Statistik-API](#42-ziel-h-19-dashboard--und-statistik-api)
   4.3 [ZIEL-H 21: Rollen- und Rechteverwaltung](#43-ziel-h-21-rollen--und-rechteverwaltung)
   4.4 [Wurf-Verwaltung und Highscore-System](#44-wurf-verwaltung-und-highscore-system)
   4.5 [Disc-Verwaltung (Scheiben)](#45-disc-verwaltung-scheiben)
   4.6 [Datenbank-Design und Schema](#46-datenbank-design-und-schema)
   4.7 [API-Architektur und Routing](#47-api-architektur-und-routing)
5. [Frontend-Implementierung (Eigene Anteile)](#5-frontend-implementierung-eigene-anteile)
   5.1 [Login-Screen](#51-login-screen)
   5.2 [Dashboard-Screen](#52-dashboard-screen)
   5.3 [Analysis-Screen (Statistikseite)](#53-analysis-screen-statistikseite)
   5.4 [Profile-Screen](#54-profile-screen)
6. [Zusammenfassung und Ausblick](#6-zusammenfassung-und-ausblick)

## 1. Einleitung und Projektkontext

### 1.1 Projektbeschreibung

Die SmartDisc-App ist eine mobile Anwendung zur Analyse von Frisbee-Würfen. Das Projekt wird in Zusammenarbeit mit einer Kollegin entwickelt, wobei der Fokus auf der Backend-Entwicklung liegt. Die Anwendung ermöglicht es Benutzern, ihre Wurf-Performance zu tracken, Statistiken zu analysieren und verschiedene SmartDisc-Geräte zu verwalten.

### 1.2 Projektziel und Motivation

Das Hauptziel des Projekts ist die Entwicklung einer robusten Backend-API, die als Grundlage für die mobile Flutter-Anwendung dient. Durch die Integration von Sensordaten aus SmartDisc-Geräten können detaillierte Analysen von Rotation, Höhe und Beschleunigung durchgeführt werden.
