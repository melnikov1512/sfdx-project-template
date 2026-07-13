/**
 * @description Test class for AccountSelector covering all public methods.
 */
@isTest
private class AccountSelectorTest {
    @TestSetup
    static void setupData() {
        TestFactory.createAdminUser();

        TestFactory.createAccount('Alpha Corp');
        TestFactory.createAccount('Beta Ltd');
        TestFactory.createAccount('Gamma Inc');
    }

    /**
     * @description Tests getRecentAccounts returns a non-empty list
     * when Accounts exist in the org.
     * Verifies that the result is not null, not empty, and does not exceed the limit of 10.
     */
    @isTest
    static void getRecentAccountsTest_Success() {
        User adminUser = TestFactory.getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.isNotNull(results, 'Result should not be null');
            Assert.isFalse(results.isEmpty(), 'Result should not be empty');
            Assert.isTrue(results.size() <= 10, 'Result should not exceed the limit of 10');
        }
    }

    /**
     * @description Tests getRecentAccounts returns accounts ordered newest first.
     * Verifies that CreatedDate of each record is >= CreatedDate of the next record.
     */
    @isTest
    static void getRecentAccountsTest_OrderedByCreatedDateDesc() {
        User adminUser = TestFactory.getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            for (Integer i = 0; i < results.size() - 1; i++) {
                Assert.isTrue(
                    results[i].CreatedDate >= results[i + 1].CreatedDate,
                    'Accounts should be ordered by CreatedDate descending'
                );
            }
        }
    }

    /**
     * @description Tests getRecentAccounts returns the expected fields:
     * Id, Name, Type, Industry, Phone, Website, CreatedDate.
     */
    @isTest
    static void getRecentAccountsTest_FieldsPopulated() {
        User adminUser = TestFactory.getAdminUser();

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.isFalse(results.isEmpty(), 'Should return at least one Account');
            Account first = results[0];
            Assert.isNotNull(first.Id, 'Id should be populated');
            Assert.isNotNull(first.Name, 'Name should be populated');
            Assert.isNotNull(first.CreatedDate, 'CreatedDate should be populated');
        }
    }

    /**
     * @description Tests getRecentAccounts returns no more than 10 records
     * even when more than 10 Accounts exist in the org.
     */
    @isTest
    static void getRecentAccountsTest_RespectsLimit() {
        User adminUser = TestFactory.getAdminUser();

        for (Integer i = 0; i < 12; i++) {
            TestFactory.createAccount('Bulk Account ' + i);
        }

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.areEqual(10, results.size(), 'Should return exactly 10 Accounts');
        }
    }

    /**
     * @description Tests getRecentAccounts returns an empty list
     * when no Accounts exist.
     */
    @isTest
    static void getRecentAccountsTest_NoAccounts() {
        User adminUser = TestFactory.getAdminUser();

        List<Account> existing = [SELECT Id FROM Account];
        delete existing;

        System.runAs(adminUser) {
            Test.startTest();
            List<Account> results = AccountSelector.getRecentAccounts();
            Test.stopTest();

            Assert.isNotNull(results, 'Result should not be null even when empty');
            Assert.areEqual(0, results.size(), 'Should return empty list when no Accounts exist');
        }
    }
}
