import java.util.Stack;

/**
 * ITP4507 SDFMS
 *
 * Holds the undo stack and the redo stack.
 * This is the history caretaker for commands. Each undoable command is
 * itself the caretaker of the memento objects it needs: it keeps them
 * and calls {@code restore()} on undo and redo.
 * A new recorded command clears the redo stack.
 * Both stacks are printed from the bottom, so the oldest line is first
 * and the next undo or redo is the last line.
 */
public class Caretaker {
    private Stack<UndoableCommand> undoStack;
    private Stack<UndoableCommand> redoStack;

    public Caretaker() {
        undoStack = new Stack<UndoableCommand>();
        redoStack = new Stack<UndoableCommand>();
    }

    /**
     * Records a command that has just been executed successfully.
     *
     * @param command the command to keep
     */
    public void record(UndoableCommand command) {
        undoStack.push(command);
        redoStack.clear();
    }

    /**
     * Undoes the most recent command.
     *
     * @return {@code false} when the undo list is empty
     */
    public boolean undo() {
        if (undoStack.isEmpty()) {
            System.out.println("Nothing to undo!");
            return false;
        }
        UndoableCommand command = undoStack.pop();
        command.undo();
        redoStack.push(command);
        System.out.println("Command (" + command.toString() + ") is undone.");
        return true;
    }

    /**
     * Redoes the most recently undone command.
     *
     * @return {@code false} when the redo list is empty
     */
    public boolean redo() {
        if (redoStack.isEmpty()) {
            System.out.println("Nothing to redo!");
            return false;
        }
        UndoableCommand command = redoStack.pop();
        command.redo();
        undoStack.push(command);
        System.out.println("Command (" + command.toString() + ") is redone.");
        return true;
    }

    /**
     * Prints both lists. Stack index 0 is the oldest entry.
     */
    public void list() {
        System.out.println("Undo List");
        for (int i = 0; i < undoStack.size(); i++) {
            System.out.println(undoStack.get(i).toString());
        }
        System.out.println("-- End of undo list --");
        System.out.println("Redo List");
        for (int i = 0; i < redoStack.size(); i++) {
            System.out.println(redoStack.get(i).toString());
        }
        System.out.println("-- End of redo list --");
    }
}
