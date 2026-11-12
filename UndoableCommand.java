/**
 * ITP4507 SDFMS
 *
 * A command whose effect can be reversed.
 * Create fleet, add driver, modify driver role, delete driver and
 * change fleet name are undoable. Show, list and set-current are not.
 * {@link #toString()} is the line printed in the undo and redo lists.
 */
public interface UndoableCommand extends Command {
    /** Reverses a successful {@link #execute()}. */
    void undo();

    /** Re-applies the command after {@link #undo()}, without asking again. */
    void redo();

    /**
     * Description captured when the command was executed.
     * Later edits must not change this text.
     */
    String toString();
}
