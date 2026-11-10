/**
 * Prints the undo list and the redo list. Listing history does not change it.
 */
public class ListHistoryCommand implements Command {

    private final SystemContext context;

    public ListHistoryCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        context.getCaretaker().showLists();
        return true;
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
