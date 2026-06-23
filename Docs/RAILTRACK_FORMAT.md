# DipRail – Formato file tracciato (.railtrack / JSON)

Questo documento descrive il formato JSON utilizzato per definire i tracciati ferroviari in DipRail.  
Il file può avere estensione `.json` o `.railtrack` ed è composto da una serie di segmenti che descrivono la geometria della linea.

## Struttura generale

Il file può contenere **uno o più tracciati**. Quando è presente un solo tracciato, la struttura è:

```json
{
  "start": { "x": 0, "y": 0, "z": 0 },
  "startDirection": 0,
  "segments": [ ... ]
}
Per supportare più tracciati (es. doppio binario), si usa l’array "tracks":

json
{
  "tracks": [
    {
      "name": "main",
      "start": { "x": 0, "y": 0, "z": 0 },
      "startDirection": 0,
      "segments": [ ... ]
    },
    {
      "name": "parallel",
      "offsetFrom": "main",
      "offset": 5,
      "segments": []       // viene copiato dal tracciato "main" e traslato lateralmente
    }
  ]
}

Parametri di partenza
Campo	Tipo	Descrizione
start	oggetto	Posizione iniziale della linea (metri). Coordinate X (est), Y (quota), Z (nord).
startDirection	numero	Angolo iniziale in gradi rispetto all'asse Z (0 = direzione +Z, 90 = +X).
segments	array	Lista dei segmenti che compongono il tracciato.
Segmenti
Ogni segmento è un oggetto con un campo obbligatorio "type" e altri parametri specifici.
I tipi supportati sono:

"straight" – rettilineo

"curve" – curva circolare

"easement" – raccordo di transizione

Segmento "straight"
Campo	Tipo	Descrizione
type	stringa	"straight"
length	numero	Lunghezza del rettilineo (metri).
grade	numero	(Opzionale) Pendenza in percentuale. Positivo = salita, negativo = discesa. Default: 0.
Esempio:

json
{ "type": "straight", "length": 100, "grade": 0.5 }
Segmento "curve"
Campo	Tipo	Descrizione
type	stringa	"curve"
radius	numero	Raggio della curva (metri). Deve essere positivo.
angle	numero	Angolo della curva in gradi. Positivo = destra, negativo = sinistra.
grade	numero	(Opzionale) Pendenza uniforme lungo la curva.
Esempio (curva a destra di 45° con raggio 500 m):

json
{ "type": "curve", "radius": 500, "angle": 45 }
Segmento "easement"
Transizione a raggio variabile, utilizzata per raccordare dolcemente un rettilineo a una curva o viceversa.
La curvatura (1/raggio) varia linearmente tra radiusStart e radiusEnd.

Campo	Tipo	Descrizione
type	stringa	"easement"
length	numero	Lunghezza del raccordo (metri).
radiusStart	numero	Raggio all'inizio del raccordo (0 = rettilineo).
radiusEnd	numero	Raggio alla fine del raccordo (0 = rettilineo).
grade	numero	(Opzionale) Pendenza.
Esempio (raccordo da rettilineo a curva di raggio 500 m):

json
{ "type": "easement", "length": 50, "radiusStart": 0, "radiusEnd": 500 }
Tracciati multipli
Per definire più binari paralleli, si può usare "offsetFrom" in un tracciato secondario. Esso copierà i segmenti del tracciato referenziato e traslerà l'intera linea lateralmente della quantità specificata in "offset" (metri). L'offset è positivo verso destra rispetto alla direzione iniziale del tracciato di riferimento.

json
{
  "tracks": [
    {
      "name": "main",
      "start": { "x": 0, "y": 0, "z": 0 },
      "startDirection": 0,
      "segments": [ ... ]
    },
    {
      "name": "second",
      "offsetFrom": "main",
      "offset": 5
    }
  ]
}

In questo caso, il secondo tracciato viene generato automaticamente parallelo al primo, distanziato di 5 metri a destra.

Metadati
Gallerie (tunnel)
Aggiungendo "tunnel": true a un segmento, lo si contrassegna come tratto in galleria. Al momento non modifica la geometria, ma il flag viene preservato per utilizzi futuri (generazione mesh galleria, illuminazione, suoni).

Esempio:

json
{ "type": "straight", "length": 200, "tunnel": true }
Esempio completo
json
{
  "tracks": [
    {
      "name": "linea1",
      "start": { "x": 0, "y": 15.0, "z": 0 },
      "startDirection": 0,
      "segments": [
        { "type": "straight", "length": 100 },
        { "type": "easement", "length": 60, "radiusStart": 0, "radiusEnd": 800 },
        { "type": "curve", "radius": 800, "angle": 30 },
        { "type": "easement", "length": 60, "radiusStart": 800, "radiusEnd": 0 },
        { "type": "straight", "length": 150, "grade": 1.2 },
        { "type": "curve", "radius": 400, "angle": -20, "grade": 1.2 },
        { "type": "straight", "length": 200, "grade": -0.8, "tunnel": true }
      ]
    }
  ]
}

Questo file genera un tracciato che parte a quota 15 m, prosegue dritto, raccorda dolcemente a una curva a destra di 30°, torna dritto in salita, curva a sinistra e infine un rettilineo in discesa in galleria.

Caricamento in DipRail
Il file JSON va posizionato nella cartella Data/Tracks/. Nella scena principale, il nodo TrackBuilder (assegnato a un Path3D) caricherà il file specificato nel parametro TrackFile. La mesh del binario verrà generata automaticamente dal nodo TrackMesh figlio.

I modder possono creare nuovi percorsi semplicemente scrivendo un nuovo JSON, senza dover modificare la scena o il codice del gioco.