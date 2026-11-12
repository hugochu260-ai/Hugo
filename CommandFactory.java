import java.util.Scanner;

/**
 * ITP4507 SDFMS
 *
 * Factory for command objects.
 * The menu codes are fixed by the assignment, so they are created in this
 * one class. Fleet creation is the part that must stay open, and that is
 * delegated to {@link VehicleFleetFactory}. Driver creation is delegated
 * to {@link DriverFactory}. No command class calls {@code new} on a fleet
 * or a driver.
 */
public class CommandFactory {
    private Scanner scanner;
    private FleetSystem system;
    private Caretaker caretaker;
    private VehicleFleetFactory fleetFactory;
    private DriverFactory driverFactory;

    /**
     * @param scanner      the shared console scanner
     * @param system       the fleet receiver
     * @param caretaker    the undo and redo history
     * @param fleetFactory the factory that creates fleets
     */
    public CommandFactory(Scanner scanner, FleetSystem system, Caretaker caretaker,
            VehicleFleetFactory fleetFactory) {
        this.scanner = scanner;
        this.system = system;
        this.caretaker = caretaker;
        this.fleetFactory = fleetFactory;
        this.driverFactory = new DriverFactory();
    }

    /**
     * @param code the menu code, already trimmed
     * @return a command ready to execute, or {@code null} when the code is unknown
     */
    public Command createCommand(String code) {
        if (code == null) {
            return null;
        }
        if (code.equals("c")) {
            return new CreateFleetCommand(scanner, system, fleetFactory);
        }
        if (code.equals("s")) {
            return new SetCurrentFleetCommand(scanner, system);
        }
        if (code.equals("a")) {
            return new AddDriverCommand(scanner, system, driverFactory, fleetFactory);
        }
        if (code.equals("m")) {
            return new ModifyDriverRoleCommand(scanner, system, fleetFactory);
        }
        if (code.equals("d")) {
            return new DeleteDriverCommand(scanner, system);
        }
        if (code.equals("sf")) {
            return new ShowFleetCommand(system);
        }
        if (code.equals("sa")) {
            return new DisplayAllFleetsCommand(system, fleetFactory);
        }
        if (code.equals("cn")) {
            return new ChangeFleetNameCommand(scanner, system);
        }
        if (code.equals("u")) {
            return new UndoCommand(caretaker);
        }
        if (code.equals("r")) {
            return new RedoCommand(caretaker);
        }
        if (code.equals("l")) {
            return new ListUndoRedoCommand(caretaker);
        }
        return null;
    }
}
