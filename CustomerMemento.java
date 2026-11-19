import java.util.Enumeration;
import java.util.Vector;

public class CustomerMemento extends Memento {
    private Customer customer;
    private Vector accounts;

    public CustomerMemento(Customer customer) {
        this.customer = customer;
        accounts = new Vector();
        Enumeration current = customer.getAllAccounts();
        while (current.hasMoreElements()) {
            accounts.addElement(current.nextElement());
        }
    }

    public void restore() {
        System.out.print("Undo - restore customer content:");

        Vector current = new Vector();
        Enumeration enumeration = customer.getAllAccounts();
        while (enumeration.hasMoreElements()) {
            current.addElement(enumeration.nextElement());
        }

        for (int i = 0; i < current.size(); i++) {
            Account account = (Account) current.elementAt(i);
            if (!accounts.contains(account)) {
                customer.removeAccount(account);
            }
        }

        for (int i = 0; i < accounts.size(); i++) {
            Account account = (Account) accounts.elementAt(i);
            if (!current.contains(account)) {
                customer.addAccount(account);
            }
        }
    }
}
