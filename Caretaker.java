import java.util.ArrayList;
import java.util.List;

/**
 * Caretaker for the undo and redo history.
 * <p>
 * The history stores Command objects, not raw mementos. Commands that change a
 * driver role or a fleet name keep their own Memento objects and restore them
 * when {@link Command#undo()} or {@link Command#redo()} is called. Commands
 * that create a fleet, add a driver, or delete a driver undo by performing the
 * inverse action.
 * </p>
 * <p>
 * Both lists are kept from the oldest entry to the newest. Undo and redo take
 * the newest entry.
 * </p>
 */
public class Caretaker {

    private final List<Command> undoList = new ArrayList<Command>();
    private final List<Command> redoList = new ArrayList<Command>();

    /**
     * Remembers a command that has just been executed. A new command clears
     * the redo list, because the discarded future no longer matches the state.
     */
    public void record(Command command) {
        undoList.add(command);
        redoList.clear();
    }

    /** Removes and returns the newest undoable command, or null when none exist. */
    public Command pollUndo() {
        if (undoList.isEmpty()) {
            return null;
        }
        return undoList.remove(undoList.size() - 1);
    }

    /** Removes and returns the newest redoable command, or null when none exist. */
    public Command pollRedo() {
        if (redoList.isEmpty()) {
            return null;
        }
        return redoList.remove(redoList.size() - 1);
    }

    public void pushRedo(Command command) {
        redoList.add(command);
    }

    /** Puts a redone command back on the undo list without clearing redo. */
    public void pushUndo(Command command) {
        undoList.add(command);
    }

    public void showLists() {
        System.out.println("Undo List");
        for (int i = 0; i < undoList.size(); i++) {
            System.out.println(undoList.get(i).getRecord());
        }
        System.out.println("-- End of undo list --");
        System.out.println("Redo List");
        for (int i = 0; i < redoList.size(); i++) {
            System.out.println(redoList.get(i).getRecord());
        }
        System.out.println("-- End of redo list --");
    }
}
