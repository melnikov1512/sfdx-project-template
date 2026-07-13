/**
 * @description Selector class for Account object. Encapsulates all SOQL queries against Account.
 */
public with sharing class AccountSelector {
    private static final Integer RECENT_ACCOUNTS_LIMIT = 10;

    /**
     * @description Returns the 10 most recently created Accounts, ordered by CreatedDate descending.
     * @return `List<Account>` Up to 10 Accounts sorted newest first
     */
    public static List<Account> getRecentAccounts() {
        return [
            SELECT Id, Name, Type, Industry, Phone, Website, CreatedDate
            FROM Account
            ORDER BY CreatedDate DESC
            LIMIT :RECENT_ACCOUNTS_LIMIT
        ];
    }
}
