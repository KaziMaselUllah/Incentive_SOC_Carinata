extensions [gis
  stats
  table
]

globals [
  GA-dataset        ; the polygon dataset
  ProfC1 ProfC2 ProfC3 ProfC4 carinataProfit t
                    ; ProfC1 = profit from corn, C2 = Cotton, C3 = Soybeans, C4 = Peanuts, AR = adoption ratio, t = time
  willingness       ; the SD value to show low or high initial willingness scenario
  phai_a            ; the lower bound for contingious diffusion to split innovators from non-innovators
  centre            ; polygons that create centre for initial diffusion in traditional diffusion theory
  TotLandAllocate   ; Total land that farmers is GA allocate for carinata
]

breed [rot1s rot1]  ; cot-cot-cot rotation
breed [rot2s rot2]  ; cot-cot-peanut rotation
breed [rot3s rot3]  ; cot-cot-corn rotation

patches-own [
  ID            ;;patch ID is identical with polygon
  cId           ;; Id at centroid of polygon
  centroid?     ;;if it is the centroid of a polygon
  myneighbors   ;;neighboring polygons' centroid patches
  cot3          ;; number of cot3 farmers on polygon
  cot2p1        ;;number of cot2p1 farmers on polygon
  cot2cr1       ;;number of cot2cr1 farmers on polygon
  Yield         ;; carinata average annual yield in ton / acre
  SOC           ;; carinata SOC rate in ton / acre
 ]

turtles-own[
  tID          ;;turtle ID is identical with polygon
  a?           ;; if farmer adopt carianta
  Wneighbors   ;;an agentset of its neighbor turtles within polygon
  Sneighbors   ;;an agentset of its neighbor turtles in surrounding polygon
  tAR          ;; adoption ration
  AT           ;; Adoption threshold
  ProfitT      ;; ProfitT = profit from tradional crop rotation without carinata
  ProfitB      ;; ProfitB = profit from crop rotation with carinata
  UtilityDifference ; profit difference from traditional crop rotation to carinata rotation
  positive1    ;; number of farmers within the polygon who got postive experiences in carinata adoption
  positive2    ;; number of farmers in surrounding polygons who got postive experiences in carinata adoption
  negetive1    ;; number of farmers within the polygon who got negetive experiences in carinata adoption
  negetive2    ;; number of farmers in sourrounding polygons who got negetive experiences in carinata adoption
  total        ;; Total number of farmers in the neighborhood (within polygon and sourrounding polygons)
  tSOC         ;; SOC rate in the county that turtle belong
  tYield       ;; Yield rate in the county that turtle belong
  Land         ;; Farmland owned by individual farmer
  LandRatio    ;; % of Land Allocate by individual farmer for carinata
  LandCarinata ;; Land Allocated for carinata by individual farmer
]

to setup
  ca
  reset-ticks

  set GA-dataset gis:load-dataset "Data.shp"       ;;loading the vector data of Georgia's counties
  gis:set-world-envelope gis:envelope-of GA-dataset

  ;; Reading data on patches
  gis:apply-coverage GA-dataset "CODEINT" ID
  gis:apply-coverage GA-dataset "SOCB" SOC       ; SOCB - Base Scenario; SOCNT - No-till scenario
  gis:apply-coverage GA-dataset "YIELDB" Yield   ;YIELDB - Base Scenario; YIELDNT - No-till scenario
  gis:apply-coverage GA-dataset "COT3" cot3
  gis:apply-coverage GA-dataset "COT2P1" cot2p1
  gis:apply-coverage GA-dataset "COT2CR1" cot2cr1


 ; each polygon identifies a patch at its centroid, which records the county numbers
  let n 1
  foreach gis:feature-list-of GA-dataset [
    feature ->
    let center-point gis:location-of gis:centroid-of feature
    ask patch item 0 center-point item 1 center-point [
      set centroid? true
      ]
    set n n + 1
  ]

;; creating neighborhood
ask patches with [ID > 0] [
    set myneighbors n-of 0 patches ;;empty agentset
  ]
  file-close
  file-open "PolygonNeighbor1.txt"

while [not file-at-end?] [
    let x file-read let y file-read
    ask patches with [ID = x ] [
      set myneighbors (patch-set myneighbors patches with [ID = y ])
    ]
  ]
  file-close


  ;;;;;; creating turtles (farmers) ;;;;;;

  foreach gis:feature-list-of GA-dataset [ feature ->
  ; creating cot-cot-cot farmers
    let target-patches1 ( patches gis:intersecting feature ) with [ gis:contained-by? self feature ]
     ; Get the number of turtles that should be in each target-patch:
      let farm1 round gis:property-value feature "Cot3" / Number_of_FarmersPerAgent    ; each unit of farmer agent represents five farmers. With exact farm numberrs the model get stuck.
    if any? target-patches1 [
     gis:create-turtles-inside-polygon feature rot1s farm1 [
        set tID ID
        ;;set tSOC SOC
       set color green
        ]
    ]
   ; creating cot-cot-peanut farmers
    let target-patches2 ( patches gis:intersecting feature ) with [ gis:contained-by? self feature ]
     ; Get the number of turtles that should be in each target-patch:
      let farm2 round gis:property-value feature "Cot2p1" / Number_of_FarmersPerAgent
    if any? target-patches2 [
     gis:create-turtles-inside-polygon feature rot2s farm2 [
        set tID ID
       ;; set tSOC SOC
       set color yellow
        ]
    ]
    ; creating cot-cot-corn farmers
    let target-patches3 ( patches gis:intersecting feature ) with [ gis:contained-by? self feature ]
     ; Get the number of turtles that should be in each target-patch:
      let farm3 round gis:property-value feature "Cot2Cr1" / Number_of_FarmersPerAgent
    if any? target-patches3 [
     gis:create-turtles-inside-polygon feature rot3s farm3 [
       set tID ID
      ;; set tSOC SOC
       set color white
        ]
    ]
 ]
ask turtles [
    ifelse SOC > -99 [set tSOC SOC ] [set tSOC "NaN"]   ;; For using GIS polygon data, just 1 or 2 turtles could be creted which has null SOC values. ;; Unit - SOC in CO2 ton per acre
  ]

 ask turtles [
    ifelse Yield > -99 [set tYield Yield] [set tYield "NaN"]   ;; For using GIS polygon data, just 1 or 2 turtles could be creted which has null Yield values. ;; Unit - Bushel/acre.
  ]
 ;;; setting paramters for initial willingess scenarios (Alexander et al., 2013)
  ifelse LowWillingness?
  [set willingness 0.102             ;; sd = 0.102 -> 2.5% innovator category
    set phai_a .025
    set centre  (list 293)]          ;; the intial county that start to adopt carianta and contain around 2.5% of farmers as innovators
  [set willingness 0.1216            ; ; sd =0.1216 -> 5% innovator category
    set phai_a .05
    set centre  (list 266 293 63)]  ;; the intial counties that start to adopt carianta and contain around 5% of farmers as innovators

 ask turtles [
    if-else TraditionalDiffusion?    ;; the rule for setting if diffusion is traditional (start from one place) or expansion (can start from all over the region)
          [ifelse ID = one-of centre or ID = one-of centre or ID = one-of centre
            [set AT 0]
                                       ;; Truncated Normal Distribution is applied because 2.5% farmers are adopter. See wiki for detail
            [ let phai_b 1             ;; Fromula:
              let miu 0.2              ;;  { x=\Phi ^{-1}(\Phi (\alpha )+ U\cdot (\Phi (\beta )-\Phi (\alpha )))\sigma +\mu}
              let sd willingness
              set AT random-float 1
              let phai_random phai_a + AT * (phai_b - phai_a)
              let phai_inverse stats:normal-inverse phai_random sd miu
              set AT phai_inverse * sd + miu
            ]
          ]
    [set AT random-normal 0.2 willingness]     ;; when the diffusion is modern
  set tAR 0
   ]

  ask turtles [
  set Land 247   ;; set the intial value 0. later apply the pecentegae distribution (see next section of the srcipts).
  set LandRatio (0.2 + random-float 0.3)
  ]

;; Draw boundary
  gis:set-drawing-color white
  gis:draw GA-dataset 1
  set t 0

end


to go
  profit
  cultivate
  ARatio
  if ticks = 11 [stop]
  plot-farmer
  plot-land
 ; report-land
  tick
end

to profit
  ;file-open "C:/ABMUpscale/Result/CornProf.txt"
  let YC1 random-normal 154 17.5
  let PC1 random-poisson 4.82
  let CC1 random-poisson 372.43
  set ProfC1 (YC1 *  PC1 - CC1)
  ;file-write t file-write ProfC1 file-print "\t"
 ; file-close

  ;file-open "C:/ABMUpscale/Result/CotProf.txt"
  let YC2a random-normal 840.9 98.4
  let PC2a random-normal  0.745 0.1
  let YC2b random-normal 1360.2 159
  let PC2b random-normal 0.08 0.02
  let CC2 random-normal 559.6 44.6
  set ProfC2 (YC2a * PC2a + YC2b * PC2b - CC2)
  ;file-write t file-write ProfC2 file-print "\t"
  ;file-close

;  let YC3 random-normal 35.8 3.7
;  let PC3 random-normal 10.96 1.8
;  let CC3 random-normal 184.86 22.9
;  set ProfC3 (YC3 *  PC3 - CC3)

 ; file-open "C:/ABMUpscale/Result/PenutProf.txt"
  let YC4 random-normal 4212.5 383.3
  let PC4 random-normal 0.21 0.03
  let CC4 random-normal 489.85 36.6
  set ProfC4 (YC4 *  PC4 - CC4)
 ; file-write t file-write ProfC4 file-print "\t"
  ;file-close

 end

to cultivate
    let NP (1 / 1.06)           ;; 6% discounted value is used to calcualte net-present value (see Upaddhaya & Dwivedi, 2019, Ag.Syst)

    ;file-open "Output.txt"  ;; Opening file for writing


    ask turtles [

    if color = green and tSOC != "NaN" and tYield != "NaN" [
    set ProfitT NP ^ (3 * t + 1) * 3 * ProfC2
    set ProfitB NP ^ (3 * t) * ProfC2 + NP ^ (3 * t + 1) * ProfC2 + NP ^ (3 * t + 1) * (CarinataPrice * tYield - CarinataCost + tSOC * SOCIncentive) + NP ^ (3 * t + 2) * 0.9 * ProfC4
    ]
    if color = yellow and tSOC != "NaN" and tYield != "NaN" [
    set ProfitT NP ^ (3 * t) * ProfC2 + NP ^ (3 * t + 1) * ProfC2 + NP ^ (3 * t + 2) * ProfC4
    set ProfitB NP ^ (3 * t) * ProfC2 + NP ^ (3 * t + 1) * ProfC2 + NP ^ (3 * t + 1) * (CarinataPrice * tYield - CarinataCost + tSOC * SOCIncentive) + NP ^ (3 * t + 2) * 0.9 * ProfC4
    ]

    if color = white and tSOC != "NaN" and tYield != "NaN" [
    set ProfitT NP ^ (3 * t) * ProfC2 + NP ^ (3 * t + 1) * ProfC2 + NP ^ (3 * t + 2) * ProfC1
    set ProfitB NP ^ (3 * t) * ProfC2 + NP ^ (3 * t + 1) * ProfC2 + NP ^ (3 * t + 1) * (CarinataPrice * tYield - CarinataCost + tSOC * SOCIncentive) + NP ^ (3 * t + 2) * ProfC1
    ]
    set UtilityDifference (ProfitB - ProfitT)

    set a? (ifelse-value
    UtilityDifference > 0  and AT <= tAR [TRUE]
                                        [FALSE])                ;; ultimately exclude the farmer who has negetive experiences in the previous time step.
   ifelse a? = true [set pcolor red] [set pcolor green]        ;;we do not assume farmers having negetive experience will never adopt energy crop.
   if a? = true [set LandCarinata Land * LandRatio]

   set TotLandAllocate precision (sum [LandCarinata] of turtles) 2

    ;file-write count turtles with [a? = TRUE] file-write  TotLandAllocate file-print "\t"
    ]
 ;file-close

end

to ARatio

ask turtles [
    set Wneighbors turtles with [tID = [tID] of myself]     ;; same polygon
    if myneighbors != 0 [set Sneighbors turtles-on [myneighbors] of patch-here] ;; surrounding polygons
    if Sneighbors != 0 [set total count Wneighbors + count Sneighbors]

    set positive1 count Wneighbors with [UtilityDifference > 0  and AT <= tAR]
    set negetive1 count Wneighbors with [UtilityDifference < 0  and AT <= tAR]
    if Sneighbors != 0 [set positive2 count Sneighbors with [UtilityDifference > 0  and AT <= tAR]]
    if Sneighbors != 0 [set negetive2 count Sneighbors with [UtilityDifference < 0  and AT <= tAR]]
    if total != 0 [set tAR (positive1 + positive2 - negetive1 - negetive2) / total]
   ]

set t t + 1
end

to plot-farmer
  set-current-plot "Biofuel Adopters"
  set-current-plot-pen "turtles"
 end

to plot-land
  set-current-plot "Total Land Allocation"
  set-current-plot-pen "land"
 end








@#$#@#$#@
GRAPHICS-WINDOW
210
10
762
563
-1
-1
4.5
1
10
1
1
1
0
1
1
1
-60
60
-60
60
0
0
1
ticks
30.0

BUTTON
28
37
91
70
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
27
91
90
124
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
789
17
1034
200
Biofuel Adopters
Rotation Steps
Number of Farmers
1.0
11.0
0.0
4000.0
false
false
"" ""
PENS
"turtles" 1.0 0 -16777216 true "" "plot count turtles with [a? = TRUE]    "

BUTTON
130
38
193
71
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
791
288
874
333
Total Adopters
count turtles with [a? = TRUE]
17
1
11

MONITOR
791
227
869
272
Total Farmers
count turtles
17
1
11

MONITOR
936
351
1041
396
Cot3 Adopters (%)
precision (count turtles with [a? = TRUE and color = green] / 3599 * 100) 2
17
1
11

TEXTBOX
1128
346
1278
364
NIL
11
0.0
1

MONITOR
1059
351
1178
396
Cpt2P1 Adopters (%)
precision (count turtles with [a? = TRUE and color = yellow] / 3599 * 100) 2
17
1
11

MONITOR
883
227
983
272
Cot3 Farmers (%)
precision (count turtles with [color = green] / 3599 * 100) 2
17
1
11

MONITOR
997
228
1111
273
Cot2P1 Famrers (%)
precision (count turtles with [color = yellow] / 3599 * 100) 2
17
1
11

MONITOR
1121
228
1237
273
Cot2Cr1 Farmers (%)
precision (count turtles with [color = white] / 3599 * 100) 2
17
1
11

MONITOR
791
350
916
395
Cot2Cr1 Adopters (%)
precision (count turtles with [a? = TRUE and color = white] / 3599 * 100) 2
17
1
11

TEXTBOX
1041
409
1302
507
|| Farmers Categories by Rotations ||\n\nCot3   : Cotton-Cotton-Cotton Farmers\nCot2P1 : Cotton-Cotton-Peanut Farmers\nCot2Cr1: Cotton-Cotton-Corn Farmers\nAdopters: Farmers who adopt carinata\n 
11
0.0
1

SLIDER
25
177
197
210
CarinataPrice
CarinataPrice
5
9
6.0
0.5
1
NIL
HORIZONTAL

SLIDER
23
255
195
288
CarinataCost
CarinataCost
260
280
270.0
10
1
NIL
HORIZONTAL

SWITCH
24
311
191
344
TraditionalDiffusion?
TraditionalDiffusion?
1
1
-1000

SWITCH
20
361
163
394
LowWillingness?
LowWillingness?
1
1
-1000

MONITOR
795
418
879
463
TotalCounties
count patches with [centroid? = true]
0
1
11

MONITOR
904
418
998
463
AdoptedCounteis
length remove-duplicates [ID] of patches with [pcolor = red]
17
1
11

MONITOR
895
287
1001
332
Total Non-adopters
3599 - count turtles with [a? = TRUE]
17
1
11

MONITOR
1019
285
1119
330
Innovators (%)
precision ((count turtles with [AT <= 0] / count turtles) * 100) 1
17
1
11

SLIDER
19
419
202
452
Number_of_FarmersPerAgent
Number_of_FarmersPerAgent
1
5
5.0
1
1
NIL
HORIZONTAL

MONITOR
1129
288
1308
333
TotalLandAlocate ('000 acre)
TotLandAllocate / 1000
17
1
11

PLOT
1043
17
1321
197
Total Land Allocation
Rotation Steps
Area ('000 acre)
1.0
11.0
0.0
350.0
false
false
"" ""
PENS
"land" 1.0 0 -16777216 true "" "plot TotLandAllocate / 1000"

SLIDER
0
138
208
171
SOCIncentive
SOCIncentive
0
200
200.0
50
1
USD/Mg CO2e
HORIZONTAL

MONITOR
1193
346
1265
391
Total NAN
count turtles with [tSOC = \"NaN\"]
17
1
11

MONITOR
801
487
898
532
VariableCheck
count turtles with [Land = 247] / count turtles
2
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="80" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="11"/>
    <metric>count turtles with [a? = TRUE and color = green]</metric>
    <metric>count turtles with [a? = TRUE and color = yellow]</metric>
    <metric>count turtles with [a? = TRUE and color = white]</metric>
    <metric>TotLandAllocate</metric>
    <enumeratedValueSet variable="CarinataPrice">
      <value value="5"/>
      <value value="5.5"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIncentive">
      <value value="0"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LowWillingness?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TraditionalDiffusion?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
