% PlantUML Filter Sample

## Sequence Diagram

```{#sequence_diagram_1 .plantuml}
@startuml
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response

Alice -> Bob: Another authentication Request
Alice <-- Bob: another authentication Response
@enduml
```

## Activity Diagram

```plantuml
@startuml activity diagram 1
start
while (データあり？) is (Yes)
  :データ読み込み<
  :グラフ出力>
endwhile (No)
stop
@enduml
```

## Component Diagram

```plantuml
@startuml

cloud "Internet" {
  database Server1
  database Server2
  database Server3
}

package "Company" {
  node Gateway
  database "Internal\nServer" as InSrv
  [Client1]
  [Client2]
  [Client3]
}

Server1 -- Gateway
Server2 -- Gateway
Server3 -- Gateway

Gateway - InSrv
Gateway -- Client1
Gateway -- Client2
Gateway -- Client3

@enduml
```
