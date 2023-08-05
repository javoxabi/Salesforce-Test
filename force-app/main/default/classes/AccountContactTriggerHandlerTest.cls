@isTest
public class AccountContactTriggerHandlerTest {

    @isTest
    static void testCheckWorkplacesBeforeInsert() {
        // Prepare test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con1 = new Contact(LastName = 'Test1');
        insert con1;

        Contact con2 = new Contact(LastName = 'Test2');
        insert con2;

        AccountContact__c accCon1 = new AccountContact__c(Account__c = acc.Id, Contact__c = con1.Id);
        AccountContact__c accCon2 = new AccountContact__c(Account__c = acc.Id, Contact__c = con2.Id);
        
        Test.startTest();
        insert new List<AccountContact__c>{accCon1, accCon2};
        Test.stopTest();

        accCon1 = [SELECT Id, isPrimary__c FROM AccountContact__c WHERE Id = :accCon1.Id];
        System.assertEquals(true, accCon1.isPrimary__c, 'accCon1 should be primary');

        accCon2 = [SELECT Id, isPrimary__c FROM AccountContact__c WHERE Id = :accCon2.Id];
        System.assertEquals(true, accCon2.isPrimary__c, 'accCon2 should be primary');
    }

    @isTest
    static void testHaveDuplicateAccountContacts() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con1 = new Contact(LastName = 'Test1');
        insert con1;

        AccountContact__c accCon1 = new AccountContact__c(Account__c = acc.Id, Contact__c = con1.Id);
        AccountContact__c accCon2 = new AccountContact__c(Account__c = acc.Id, Contact__c = con1.Id);

        Test.startTest();
        insert accCon1;

        Database.SaveResult result = Database.insert(accCon2, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Insert should have failed due to duplicate AccountContact');
        System.assertEquals('Duplicate AccountContact found in existing data', result.getErrors()[0].getMessage(), 'Wrong test datas');
    }


    @isTest
    static void testPreventUpdateIfOneAccountContact() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con1 = new Contact(LastName = 'Test1');
        insert con1;

        AccountContact__c accCon1 = new AccountContact__c(Account__c = acc.Id, Contact__c = con1.Id, IsPrimary__c = true);
        insert accCon1;

        Test.startTest();
        accCon1.IsPrimary__c = false;
        Database.SaveResult result = Database.update(accCon1, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Update should have failed because IsPrimary__c cannot be set to false for the only AccountContact record for a Contact');
        System.assertEquals('Cannot update isPrimary to false for ' + accCon1.Id + ' - There is only one AccountContact', result.getErrors()[0].getMessage(), 'Wrong Test Datas');
    }


    @isTest
    static void testUpdateIsPrimary() {
        Account acc1 = new Account(Name = 'Test Account 1');
        Account acc2 = new Account(Name = 'Test Account 2');
        insert new List<Account>{acc1, acc2};
        
        Contact con = new Contact(LastName = 'Test');
        insert con;

        AccountContact__c accCon1 = new AccountContact__c(Account__c = acc1.Id, Contact__c = con.Id, IsPrimary__c = true);
        AccountContact__c accCon2 = new AccountContact__c(Account__c = acc2.Id, Contact__c = con.Id, IsPrimary__c = false);
        insert new List<AccountContact__c>{accCon1, accCon2};

        Test.startTest();
        accCon2.IsPrimary__c = true;
        update accCon2;
        Test.stopTest();

        accCon1 = [SELECT IsPrimary__c FROM AccountContact__c WHERE Id = :accCon1.Id];
        System.assertEquals(false, accCon1.IsPrimary__c, 'IsPrimary__c should have been set to false for the other AccountContact record');

        accCon2.IsPrimary__c = false;
        update accCon2;

        accCon1 = [SELECT IsPrimary__c FROM AccountContact__c WHERE Id = :accCon1.Id];
        System.assertEquals(true, accCon1.IsPrimary__c, 'IsPrimary__c should have been set to true for the other AccountContact record');
    }


    @isTest
    static void testHandlePrimaryAfterDelete() {

        Account acc1 = new Account(Name = 'Test Account 1');
        Account acc2 = new Account(Name = 'Test Account 2');
        Account acc3 = new Account(Name = 'Test Account 3');
        insert new List<Account>{acc1, acc2, acc3};
        
        Contact con = new Contact(LastName = 'Test');
        insert con;

        AccountContact__c accCon1 = new AccountContact__c(Account__c = acc1.Id, Contact__c = con.Id, IsPrimary__c = true);
        AccountContact__c accCon2 = new AccountContact__c(Account__c = acc2.Id, Contact__c = con.Id, IsPrimary__c = false);
        AccountContact__c accCon3 = new AccountContact__c(Account__c = acc3.Id, Contact__c = con.Id, IsPrimary__c = false);
        insert new List<AccountContact__c>{accCon1, accCon2, accCon3};

        Test.startTest();
        delete accCon1;
        Test.stopTest();

        accCon2 = [SELECT IsPrimary__c FROM AccountContact__c WHERE Id = :accCon2.Id];
        System.assertEquals(true, accCon2.IsPrimary__c, 'IsPrimary__c should have been set to true for the most recently created AccountContact record');

        accCon3 = [SELECT IsPrimary__c FROM AccountContact__c WHERE Id = :accCon3.Id];
        System.assertEquals(false, accCon3.IsPrimary__c, 'IsPrimary__c should have been set to false for the other AccountContact record');
    }



}
