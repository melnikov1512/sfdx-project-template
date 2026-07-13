/**
 * @description Factory class for creating test data.
 * Provides reusable methods for generating SObjects and users in test context.
 * All user creation is wrapped in System.runAs to prevent MIXED_DML errors.
 */
@isTest
public class TestFactory {
    /**
     * @description Creates an admin user with System Administrator profile.
     * Wraps insert in System.runAs to avoid MIXED_DML errors.
     * @return `User` The created admin user
     */
    public static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            Alias = 'admtest',
            Email = 'admintest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admintest@example.com.' + System.currentTimeMillis()
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    /**
     * @description Retrieves the admin user created in @TestSetup.
     * @return `User` The admin test user
     */
    public static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'admintest@example.com' LIMIT 1];
    }

    /**
     * @description Creates and inserts an Account record with the given name.
     * @param name `String` Account name
     * @return `Account` The inserted Account record
     */
    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }
}
