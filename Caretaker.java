import java.util.Vector;

public class Caretaker {
    private Vector undoList;

    public Caretaker() {
        undoList = new Vector();
    }

    public void saveAccount(Account account) {
        undoList.addElement(new AccountMemento(account));
    }

    public void saveCustomer(Customer customer) {
        undoList.addElement(new CustomerMemento(customer));
    }

    public void undo() {
        if (undoList.isEmpty()) {
            return;
        }
        Memento memento = (Memento) undoList.remove(undoList.size() - 1);
        memento.restore();
    }
}
