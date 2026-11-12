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
        System.out.println("Smart Delivery Fleet Management System (SDFMS)");
        System.out.println("c = create fleet, s = set current fleet, a = add driver, m = modify driver role,");
        System.out.println("d = delete driver, sf = show fleet, sa = display all fleets, cn = change fleet name,");
        System.out.println("u = undo, r = redo, l = list undo/redo, x = exit system");
        if (current != null) {
            System.out.println("The current fleet is " + current.getFleetID()
                    + " " + current.getName() + ".");
        }
        System.out.print("Please enter command [ c | s | a | m | d | sf | sa | cn | u | r | l | x ] :- ");
    }
}
