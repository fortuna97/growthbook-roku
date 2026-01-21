'
' GrowthBook Roku SDK - Group Targeting Example
' 
' This example shows how to:
' 1. Use savedGroups for pre-defined group targeting
' 2. Target users with $inGroup operator
' 3. Exclude users with $notInGroup operator
' 4. Common use cases: beta testers, VIP users, A/B test cohorts
'

function Main()
    ' 1. Initialize with savedGroups
    '
    ' savedGroups are pre-defined lists of user IDs
    ' These are typically synced from your GrowthBook dashboard
    ' or loaded from your backend
    
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: "user_12345",
            email: "user@example.com",
            country: "US"
        },
        
        ' savedGroups: map of group_id -> array of member values
        ' These groups are defined in your GrowthBook dashboard
        savedGroups: {
            ' Beta testers group
            "beta_testers": ["user_12345", "user_67890", "user_11111"],
            
            ' VIP customers group
            "vip_customers": ["user_99999", "user_88888"],
            
            ' Internal employees
            "employees": ["emp_001", "emp_002", "emp_003"],
            
            ' Banned users (for exclusion)
            "banned_users": ["user_banned_1", "user_banned_2"]
        },
        
        enableDevMode: true
    }
    
    gb = GrowthBook(config)
    
    if gb.init()
        print "✓ GrowthBook initialized with savedGroups"
    else
        print "✗ Failed to initialize"
        return
    end if
    
    ' 2. Target beta testers with $inGroup
    '
    ' In GrowthBook dashboard, configure targeting:
    ' { "id": { "$inGroup": "beta_testers" } }
    '
    ' This matches if user's id is in the beta_testers group
    
    print ""
    print "=== Beta Tester Targeting ==="
    if gb.isOn("new-ui-redesign")
        print "✓ New UI enabled (user is in beta_testers group)"
        showNewUI()
    else
        print "✗ Using standard UI"
    end if
    
    ' 3. VIP-only features with $inGroup
    '
    ' { "id": { "$inGroup": "vip_customers" } }
    
    print ""
    print "=== VIP Features ==="
    if gb.isOn("vip-early-access")
        print "✓ VIP early access enabled"
    else
        print "✗ VIP early access not available (user not in vip_customers)"
    end if
    
    ' 4. Exclude banned users with $notInGroup
    '
    ' { "id": { "$notInGroup": "banned_users" } }
    '
    ' This passes if user is NOT in the banned group
    
    print ""
    print "=== Access Control ==="
    if gb.isOn("premium-content")
        print "✓ Premium content accessible (user not banned)"
    else
        print "✗ Premium content blocked"
    end if
    
    ' 5. Combine with other conditions
    '
    ' You can combine $inGroup with other operators:
    ' {
    '   "$and": [
    '     { "id": { "$inGroup": "beta_testers" } },
    '     { "country": { "$in": ["US", "CA"] } }
    '   ]
    ' }
    
    print ""
    print "=== Combined Targeting ==="
    if gb.isOn("us-beta-feature")
        print "✓ US beta feature enabled (beta tester + US country)"
    else
        print "✗ US beta feature not available"
    end if
    
    ' 6. Update user and re-evaluate
    print ""
    print "=== Switching to VIP User ==="
    
    gb.setAttributes({
        id: "user_99999",  ' This user is in vip_customers
        email: "vip@example.com",
        country: "US"
    })
    
    if gb.isOn("vip-early-access")
        print "✓ VIP early access now enabled for user_99999"
    end if
    
    ' 7. Display group membership status
    print ""
    print "=== Group Membership ==="
    print "  beta_testers: [user_12345, user_67890, user_11111]"
    print "  vip_customers: [user_99999, user_88888]"
    print "  Current user (user_99999) is in: vip_customers"
    
end function

function showNewUI()
    print "  [Beta] Loading new UI redesign..."
end function

