/**
 * @description Test class for AccountSelector covering all public methods.
 */
@isTest
private class AccountSelectorTest {
    @TestSetup
    static void setupData() {
        TestFactory.createAdminUser();
    }

    /**
     * @description Tests getRecentAccounts returns inserted accounts with expected fields populated.
     * Verifies that Id, Name, and CreatedDate are present on returned records.
     */
    @isTest
    static void getRecentAccountsTestReturnsAccounts() {
        User adminUser = TestFactory.getAdminUser();

        TestFactory.createAccount('Alpha Corp');
        TestFactory.createAccount('Beta LLC');

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.isFalse(results.isEmpty(), 'Should return accounts when records exist');
            Assert.areEqual(2, results.size(), 'Should return both inserted accounts');
            Assert.isNotNull(results[0].Id, 'Id field should be populated');
            Assert.isNotNull(results[0].Name, 'Name field should be populated');
            Assert.isNotNull(results[0].CreatedDate, 'CreatedDate field should be populated');
        }
    }

    /**
     * @description Tests getRecentAccounts enforces the 10-record limit.
     * Verifies that at most 10 accounts are returned even when more exist.
     */
    @isTest
    static void getRecentAccountsTestRespectsLimit() {
        User adminUser = TestFactory.getAdminUser();

        List<Account> accounts = new List<Account>();
        for (Integer i = 1; i <= 15; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i));
        }
        insert accounts;

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.areEqual(10, results.size(), 'Should return at most 10 accounts');
        }
    }

    /**
     * @description Tests getRecentAccounts returns an empty list when no accounts exist.
     * Verifies safe handling of empty data sets.
     */
    @isTest
    static void getRecentAccountsTestEmptyOrg() {
        User adminUser = TestFactory.getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.isNotNull(results, 'Result list should never be null');
            Assert.areEqual(0, results.size(), 'Should return empty list when no accounts exist');
        }
    }

    /**
     * @description Tests getRecentAccounts returns records ordered newest first.
     * Verifies ORDER BY CreatedDate DESC using Test.setCreatedDate to simulate time gap.
     */
    @isTest
    static void getRecentAccountsTestOrderedByCreatedDateDesc() {
        User adminUser = TestFactory.getAdminUser();

        Account older = TestFactory.createAccount('Older Account');
        Account newer = TestFactory.createAccount('Newer Account');

        Test.setCreatedDate(older.Id, DateTime.now().addDays(-2));
        Test.setCreatedDate(newer.Id, DateTime.now());

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.areEqual(2, results.size(), 'Should return both accounts');
            Assert.areEqual(newer.Id, results[0].Id, 'Most recently created account should be first');
            Assert.areEqual(older.Id, results[1].Id, 'Older account should be second');
        }
    }
}
