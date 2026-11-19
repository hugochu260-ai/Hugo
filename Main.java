import java.io.*;
import java.util.*;

public class Main {
	public static void main(String args[]) {
		Main driver = new Main();
		driver.Start();
	} // main 

	public void Start() {

		// Peter has two accounts 
		Customer peter = new Customer("Peter", "Wanchai");
		Account a1 = new Account("INT001", 100);
		Account a2 = new Account("INT002", 200);
		peter.addAccount(a1); peter.addAccount(a2);

		// Prepare a Caretaker for  the undo operation
		Caretaker ct = new Caretaker();  

		// print out
		System.out.println( "SuperBank Customer: " + peter.getName() + " "
				+ "at address: " + peter.getAddress());
		for (Enumeration xx = peter.getAllAccounts();
				xx.hasMoreElements();) {
			Account x = (Account)(xx.nextElement());
			System.out.println("Account Number: " + x.getAccountNumber() + " "
					+ "has balance " + x.getBalance());
		} // for end

		// Do some transaction
		ct.saveAccount(peter.getAccount("INT001"));
		peter.getAccount("INT001").increase(50);

		ct.saveAccount(peter.getAccount("INT001"));
		peter.getAccount("INT001").decrease(20);

		ct.saveCustomer(peter);
		peter.removeAccount(peter.getAccount("INT002"));

		// undo now
		ct.undo();
		ct.undo();
		ct.undo();

		// print out
		System.out.println( "SuperBank Customer: " + peter.getName() + " "
				+ "at address: " + peter.getAddress());
		for (Enumeration xx = peter.getAllAccounts();
				xx.hasMoreElements();) {
			Account x = (Account)(xx.nextElement());
			System.out.println("Account Number: " + x.getAccountNumber() + " "
					+ "has balance " + x.getBalance());
		} // for end

	} // driver
} // Main Driver Program
