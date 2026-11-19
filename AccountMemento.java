public class AccountMemento extends Memento {
    private Account account;
    private double balance;

    public AccountMemento(Account account) {
        this.account = account;
        balance = account.getBalance();
    }

    public void restore() {
        account.setBalance(balance);
        System.out.println("Undo - restore account value:restore account no: "
                + account.getAccountNumber() + " balance " + balance);
    }
}
