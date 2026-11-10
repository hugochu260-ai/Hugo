/**
 * Refrigerated truck fleet. Role 1 is a refrigerated-truck driver and role 2
 * is a cold-chain delivery driver.
 */
public class RefrigeratedTruckFleet extends VehicleFleet {

    private final int REFRIGERATED_TRUCK_DRIVER_ROLE = 1;
    private final int COLD_CHAIN_DELIVERY_DRIVER_ROLE = 2;

    @SuppressWarnings("this-escape")
    public RefrigeratedTruckFleet(String fleetID) {
        super(fleetID);
        defineRole(REFRIGERATED_TRUCK_DRIVER_ROLE, "refrigerated-truck driver", "Refrigerated-Truck Driver");
        defineRole(COLD_CHAIN_DELIVERY_DRIVER_ROLE, "cold-chain delivery driver", "Cold-Chain Delivery Driver");
    }

    @Override
    public void updateDriverRole() {
        Driver driver = getPendingDriver();
        int role = getPendingRole();
        if (driver != null
                && (role == REFRIGERATED_TRUCK_DRIVER_ROLE || role == COLD_CHAIN_DELIVERY_DRIVER_ROLE)) {
            driver.setRole(role);
        }
    }

    @Override
    public void showFleet() {
        printFleet();
    }

    @Override
    public String getTypeCode() {
        return "r";
    }

    @Override
    public String getKindTitle() {
        return "Refrigerated Truck Fleet";
    }

    @Override
    public String getHistoryName() {
        return "refrigerated truck fleet";
    }

    @Override
    public String getCreatedMessage() {
        return "Refrigerated truck fleet is created.";
    }
}
