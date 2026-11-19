package MyPackage;

import java.util.Vector;

public class Caretaker {
    private Vector undoList;

    public Caretaker() {
        undoList = new Vector();
    }

    public void saveMyClass(MyClass mc) {
        undoList.addElement(new Memento(mc));
    }

    public void undo() {
        if (undoList.isEmpty()) {
            return;
        }
        Memento memento = (Memento) undoList.remove(undoList.size() - 1);
        memento.restore();
    }
}
