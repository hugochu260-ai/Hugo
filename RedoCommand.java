/**
 * Redoes the newest command on the caretaker's redo list.
 * The command returns to the undo list without clearing the rest of the redo list.
 */
public class RedoCommand implements Command {

    private final SystemContext context;

    public RedoCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        Command command = context.getCaretaker().pollRedo();
        if (command == null) {
            System.out.println("Nothing to redo!");
            return false;
        }
        command.redo();
        context.getCaretaker().pushUndo(command);
        System.out.println("Command (" + command.getRecord() + ") is redone.");
        return false;
    }

    @Override
    public void undo() {
    }

    @Override
    public void redo() {
    }

    @Override
    public boolean isUndoable() {
        return false;
    }

    @Override
    public String getRecord() {
        return "";
    }
}
