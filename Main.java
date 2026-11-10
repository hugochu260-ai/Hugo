/**
 * Entry point and Invoker of the Command pattern.
 * <p>
 * The loop prints the menu, asks {@link CommandFactory} for a command, and
 * executes it. Successful undoable commands are handed to the {@link Caretaker}.
 * </p>
 */
public class Main {

    public static void main(String[] args) {
        FleetFactoryProvider provider = new FleetFactoryProvider();
        provider.register(new DeliveryVanFleetFactory());
        provider.register(new RefrigeratedTruckFleetFactory());

        SystemContext context = new SystemContext(
                new FleetManager(),
                new Caretaker(),
                new java.util.Scanner(System.in),
                provider);
        new Main().run(context);
    }

    private void run(SystemContext context) {
        while (true) {
            printMenu(context);
            String commandText = context.readLine(
                    "Please enter command [ c | s | a | m | d | sf | sa | cn | u | r | l | x ] :- ");
            if (commandText == null || "x".equals(commandText)) {
                if (commandText == null) {
                    System.out.println();
                }
                System.out.println("Thank you for using SDFMS. System terminated.");
                return;
            }
            Command command = CommandFactory.create(commandText, context);
            if (command == null) {
                System.out.println("Invalid command!");
                continue;
            }
            boolean succeeded = command.execute();
            if (succeeded && command.isUndoable()) {
                context.getCaretaker().record(command);
            }
        }
    }

    private void printMenu(SystemContext context) {
        System.out.println("Smart Delivery Fleet Management System (SDFMS)");
        System.out.println("c = create fleet, s = set current fleet, a = add driver, m = modify driver role,");
        System.out.println("d = delete driver, sf = show fleet, sa = display all fleets, cn = change fleet name,");
        System.out.println("u = undo, r = redo, l = list undo/redo, x = exit system");
        VehicleFleet current = context.getManager().getCurrentFleet();
        if (current != null) {
            System.out.println("The current fleet is " + current.getFleetID() + " " + current.getName() + ".");
        }
    }
}
