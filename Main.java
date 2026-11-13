// Prints the menu, runs the command, and records a successful undoable command. Exit stays here.
import java.util.Scanner;

public class Main {

    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        FleetSystem system = new FleetSystem();
        Caretaker caretaker = new Caretaker();
        VehicleFleetFactory fleetFactory = new VehicleFleetFactory();
        CommandFactory commandFactory = new CommandFactory(scanner, system, caretaker, fleetFactory);

        while (true) {
            printMenu(system.getCurrentFleet());
            String code = scanner.nextLine().trim();
            if (code.equals("x")) {
                System.out.println("Thank you for using SDFMS. System terminated.");
                break;
            }

            Command command = commandFactory.createCommand(code);
            if (command == null) {
                System.out.println("Invalid command!");
                continue;
            }

            boolean success = command.execute();
            if (success && command instanceof UndoableCommand) {
                caretaker.record((UndoableCommand) command);
            }
        }
        scanner.close();
    }

    private static void printMenu(VehicleFleet current) {
        System.out.println();
        System.out.println("==============================================");
        System.out.println("  Smart Delivery Fleet Management System");
        System.out.println("  SDFMS");
        System.out.println("==============================================");
        if (current == null) {
            System.out.println("  Current fleet : (none)");
        } else {
            System.out.println("  Current fleet : " + current.getFleetID()
                    + "  " + current.getName());
        }
        System.out.println("----------------------------------------------");
        System.out.println("  Fleet");
        System.out.println("    c   create fleet");
        System.out.println("    s   set current fleet");
        System.out.println("    sf  show fleet");
        System.out.println("    sa  display all fleets");
        System.out.println("    cn  change fleet name");
        System.out.println("  Driver");
        System.out.println("    a   add driver");
        System.out.println("    m   modify driver role");
        System.out.println("    d   delete driver");
        System.out.println("  History");
        System.out.println("    u   undo");
        System.out.println("    r   redo");
        System.out.println("    l   list undo/redo");
        System.out.println("  Exit");
        System.out.println("    x   exit system");
        System.out.println("----------------------------------------------");
        System.out.print("Command [ c | s | a | m | d | sf | sa | cn | u | r | l | x ] :- ");
    }
}
