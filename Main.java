import java.util.Scanner;

/**
 * ITP4507 SDFMS
 *
 * Client of the command pattern. The loop prints the menu, asks
 * {@link CommandFactory} for a command, and executes it. A successful
 * {@link UndoableCommand} is given to the {@link Caretaker}.
 * Exit is handled here. The assignment's command list does not include
 * exit, so exit is not a command object.
 */
public class Main {
    /**
     * Starts the console application.
     *
     * @param args unused
     */
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

    /**
     * Prints the title and the command menu.
     * The current-fleet line is printed only after a fleet has been selected.
     *
     * @param current the current fleet, or {@code null} when none is selected
     */
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
