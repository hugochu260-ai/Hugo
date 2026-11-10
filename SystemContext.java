import java.util.Scanner;

/**
 * Shared collaborators passed to every command: the fleet receiver, the
 * undo caretaker, the input scanner, and the fleet factories.
 */
public class SystemContext {

    private final FleetManager manager;
    private final Caretaker caretaker;
    private final Scanner scanner;
    private final FleetFactoryProvider fleetFactories;

    public SystemContext(FleetManager manager, Caretaker caretaker, Scanner scanner,
                         FleetFactoryProvider fleetFactories) {
        this.manager = manager;
        this.caretaker = caretaker;
        this.scanner = scanner;
        this.fleetFactories = fleetFactories;
    }

    public FleetManager getManager() {
        return manager;
    }

    public Caretaker getCaretaker() {
        return caretaker;
    }

    public FleetFactoryProvider getFleetFactories() {
        return fleetFactories;
    }

    /**
     * Prints {@code prompt} and reads the next line.
     *
     * @return the trimmed line, or {@code null} at end of input
     */
    public String readLine(String prompt) {
        System.out.print(prompt);
        System.out.flush();
        if (!scanner.hasNextLine()) {
            return null;
        }
        return scanner.nextLine().trim();
    }
}
