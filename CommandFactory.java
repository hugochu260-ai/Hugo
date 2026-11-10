/**
 * Simple Factory that turns a menu token into a Command object.
 * <p>
 * The invoker ({@link Main}) does not construct concrete commands. Adding a
 * menu command means adding one branch here and one command class.
 * </p>
 */
public final class CommandFactory {

    private CommandFactory() {
    }

    public static Command create(String token, SystemContext context) {
        if (token == null) {
            return null;
        }
        if ("c".equals(token)) {
            return new CreateFleetCommand(context);
        }
        if ("s".equals(token)) {
            return new SetCurrentFleetCommand(context);
        }
        if ("a".equals(token)) {
            return new AddDriverCommand(context);
        }
        if ("m".equals(token)) {
            return new ModifyDriverRoleCommand(context);
        }
        if ("d".equals(token)) {
            return new DeleteDriverCommand(context);
        }
        if ("sf".equals(token)) {
            return new ShowFleetCommand(context);
        }
        if ("sa".equals(token)) {
            return new DisplayAllFleetsCommand(context);
        }
        if ("cn".equals(token)) {
            return new ChangeFleetNameCommand(context);
        }
        if ("u".equals(token)) {
            return new UndoCommand(context);
        }
        if ("r".equals(token)) {
            return new RedoCommand(context);
        }
        if ("l".equals(token)) {
            return new ListHistoryCommand(context);
        }
        return null;
    }
}
