// Creates the command object for a menu code.
import java.util.Scanner;

public class CommandFactory {
    private Scanner scanner;
    private FleetSystem system;
    private Caretaker caretaker;
    private VehicleFleetFactory fleetFactory;
    private DriverFactory driverFactory;

    public CommandFactory(Scanner scanner, FleetSystem system, Caretaker caretaker,
            VehicleFleetFactory fleetFactory) {
        this.scanner = scanner;
        this.system = system;
        this.caretaker = caretaker;
        this.fleetFactory = fleetFactory;
        this.driverFactory = new DriverFactory();
    }

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
