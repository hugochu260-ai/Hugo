import java.util.Enumeration;
import java.util.Hashtable;

public class Customer {
    private String name;
    private String address;
    private Hashtable accounts;

    public Customer(String name, String address) {
        this.name = name;
        this.address = address;
        accounts = new Hashtable();
        System.out.println("Customer: " + name + " is created.");
    }

    public String getName() {
        return name;
    }

    public String getAddress() {
        return address;
    }

    public void addAccount(Account account) {
        accounts.put(account.getAccountNumber(), account);
        System.out.println("--- add account : " + account.getAccountNumber());
    }

    public void removeAccount(Account account) {
        accounts.remove(account.getAccountNumber());
        System.out.println("--- remove account : " + account.getAccountNumber());
    }

    public Account getAccount(String accountNumber) {
        return (Account) accounts.get(accountNumber);
    }

    public Enumeration getAllAccounts() {
        return accounts.elements();
    }
}
