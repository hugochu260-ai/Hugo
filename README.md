# Smart Delivery Fleet Management System

Console application for ITP4507 Assignment One.

The program keeps delivery-van fleets and refrigerated-truck fleets, the drivers on those fleets, and an undo/redo history. Every menu action is a Command. Fleets and drivers are created by factories. Changing a driver role or a fleet name is undone with the Memento pattern.

## Run

On Windows, from this folder:

```bat
run.bat
```

That file compiles every `.java` file in the folder and starts `Main`.

On Linux or macOS:

```sh
javac *.java
java Main
```

`run.sh` does the same two steps.

## Report

The written report, class diagrams, and screen captures are in [report/index.html](report/index.html). A PDF copy is `ITP4507_Assignment1_Report.pdf`.

Write your student number on the report cover before handing in.

## Check

`tests/check_sdfms.py` replays the assignment sample and the extra cases against `java Main`.
