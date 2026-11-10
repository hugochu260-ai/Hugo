/**
 * Undoes the newest command on the caretaker's undo list.
 * The undo action itself is not recorded as another command.
 */
public class UndoCommand implements Command {

    private final SystemContext context;

    public UndoCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        Command command = context.getCaretaker().pollUndo();
        if (command == null) {
            System.out.println("Nothing to undo!");
            return false;
        }
        command.undo();
        context.getCaretaker().pushRedo(command);
        System.out.println("Command (" + command.getRecord() + ") is undone.");
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
