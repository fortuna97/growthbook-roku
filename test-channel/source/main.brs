sub Main()
    print "GrowthBook SDK Test Channel Starting..."

    testResults = RunSDKTests()

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    scene = screen.CreateScene("TestScene")
    screen.show()
    scene.callFunc("displayResults", testResults)

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed()
            exit while
        end if
    end while

    print "GrowthBook SDK Test Channel Completed"
end sub
