/**
 * Creates a vehicle fleet through the Abstract Factory and makes it current.
 * <p>
 * Undo removes that fleet and restores the fleet that was current beforehand.
 * Redo puts the same fleet object back, so later driver commands that point at
 * it remain valid. The fleet is created only once; redo does not construct a
 * second one.
 * </p>
 */
public class CreateFleetCommand implements Command {

    private final SystemContext context;
    private VehicleFleet fleet;
    private VehicleFleet previousCurrent;
    private String record = "";

    public CreateFleetCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        FleetFactoryProvider provider = context.getFleetFactories();
        String type = context.readLine(provider.buildTypePrompt());
        if (type == null) {
            return false;
        }
        FleetComponentFactory factory = provider.getFactory(type);
        if (factory == null) {
            System.out.println("Invalid fleet type!");
            return false;
        }
        String fleetID = context.readLine("Fleet ID:- ");
        if (fleetID == null) {
            return false;
        }
        String fleetName = context.readLine("Fleet Name:- ");
        if (fleetName == null) {
            return false;
        }
        if (fleetID.length() == 0) {
            System.out.println("Fleet ID cannot be empty!");
            return false;
        }
        if (fleetName.length() == 0) {
            System.out.println("Fleet name cannot be empty!");
            return false;
        }
        if (context.getManager().findFleet(fleetID) != null) {
            System.out.println("Fleet " + fleetID + " already exists!");
            return false;
        }

        fleet = factory.createFleet(fleetID);
        fleet.setName(fleetName);
        previousCurrent = context.getManager().getCurrentFleet();
        context.getManager().addFleet(fleet);
        context.getManager().setCurrentFleet(fleet);
        record = "Create " + fleet.getHistoryName() + ", " + fleet.getFleetID() + ", " + fleet.getName();
        System.out.println(fleet.getCreatedMessage());
        System.out.println("Current fleet is changed to " + fleet.getFleetID() + ".");
        return true;
    }

    @Override
    public void undo() {
        context.getManager().removeFleet(fleet);
        context.getManager().setCurrentFleet(previousCurrent);
    }

    @Override
    public void redo() {
        context.getManager().addFleet(fleet);
        context.getManager().setCurrentFleet(fleet);
    }

    @Override
    public boolean isUndoable() {
        return true;
    }

    @Override
    public String getRecord() {
        return record;
    }
}
