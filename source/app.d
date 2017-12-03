import core.thread;
import core.time;

import std.net.curl;
import std.stdio;
import std.string;
import std.conv;
import std.random;
import std.getopt;
import std.json;

string genUuid()
{
    return format("%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
        // 32 bits for "time_low"
        uniform(0, 0xffff), uniform(0, 0xffff),

        // 16 bits for "time_mid"
        uniform(0, 0xffff),

        // 16 bits for "time_hi_and_version",
        // four most significant bits holds version number 4
        uniform(0, 0x0fff) | 0x4000,

        // 16 bits, 8 bits for "clk_seq_hi_res",
        // 8 bits for "clk_seq_low",
        // two most significant bits holds zero and one for variant DCE1.1
        uniform(0, 0x3fff) | 0x8000,

        // 48 bits for "node"
        uniform(0, 0xffff), uniform(0, 0xffff), uniform(0, 0xffff)
    );
}

class PoolRequest : Thread
{
    this()
    {
        super(&run);
    }

    pure int failed() const
    {
        return failedRequests;
    }

    pure int succeded() const
    {
        return succededRequests;
    }

    void setVerbose(bool verbose = true)
    {
        this.verbose = verbose;
    }

protected:
    abstract void run();

protected:
    int failedRequests = 0;
    int succededRequests = 0;
    bool verbose = false;
}

class GetWorkersRequest : PoolRequest
{
    this(int countRequests, const string url)
    {
        this.n = countRequests;
        this.url = url;

        super();
    }

protected:
    override void run()
    {
        writeln("Started " ~ to!string(n) ~ " requests.");

        for (auto i = 0; i != n; ++i)
        {
            try
            {
                string requestData = "";

                auto http = HTTP();
                http.addRequestHeader("Content-Type", "application/json;charset=utf-8");
                http.connectTimeout(seconds(30));

                auto response = get(url, http);
                
                if (verbose)
                {
                    writeln("RESPONSE: " ~ response);
                }
                
                auto jsonResponse = parseJSON(response);
                ++succededRequests;
            }
            catch (std.exception.Exception ex)
            {
                writeln("Error! Exception: " ~ ex.msg);
                ++failedRequests;
            }

            if ((i % 100) == 0)
            {
                writeln(format("Processed %d requests.", i + 1));
            }
        }

        writeln("Finished processing " ~ to!string(n) ~ " requests.");
    }

    private :
        const string url;
        const int n;
}

class StatAddressRequest : PoolRequest
{
    this(int countRequests, const string url)
    {
        this.n = countRequests;
        this.url = url;

        super();
    }

protected:
    override void run()
    {
        writeln("Started " ~ to!string(n) ~ " requests.");

        for (auto i = 0; i != n; ++i)
        {
            try
            {
                string requestData = "";

                auto http = HTTP();
                http.addRequestHeader("Content-Type", "application/json;charset=utf-8");
                http.connectTimeout(seconds(30));

                auto response = get(url, http);

                if (verbose)
                {
                    writeln("RESPONSE: " ~ response);
                }
                
                auto jsonResponse = parseJSON(response);
                ++succededRequests;
            }
            catch (std.exception.Exception ex)
            {
                writeln("Error! Exception: " ~ ex.msg);
                ++failedRequests;
            }

            if ((i % 100) == 0)
            {
                writeln(format("Processed %d requests.", i + 1));
            }
        }

        writeln("Finished processing " ~ to!string(n) ~ " requests.");
    }

    private :
        const string url;
        const int n;
}

void main(string[] args)
{
    bool verbose = false;

    string poolUrl = "";
    string getWorkersUrl = "";
    string statAddressUrl = "";
    string walletAddress = "";

    int countThreads = 10;
    int countRequestsPerThread = 10;

    auto helpInformation = args.getopt(
        "threads", "Count requests threads.", &countThreads,
        "requestsPerThread", "Count requests per each thread.", &countRequestsPerThread,
        "poolUrl", "Pool URL.", &poolUrl,
        "getWorkersUrl", "Pool GetWorkersUrl.", &getWorkersUrl,
        "statAddressUrl", "Pool StatAddressUrl.", &statAddressUrl,
        "walletAddress", "Wallet Address.", &walletAddress,
        "verbose", "Add more debug information", &verbose
    );

    if (helpInformation.helpWanted || poolUrl.empty() || (walletAddress.empty() && getWorkersUrl.empty() && statAddressUrl.empty()))
    {
        defaultGetoptPrinter("Pool tests.", helpInformation.options);

        return;
    }

    if (getWorkersUrl.empty())
    {
        getWorkersUrl = poolUrl ~ "/workers_address?address=" ~ walletAddress;
    }

    if (statAddressUrl.empty())
    {
        statAddressUrl = poolUrl ~ "/stats_address?address=" ~ walletAddress;
    }

    writeln("Pool URL: " ~ poolUrl);
    writeln("Get Workers URL: " ~ getWorkersUrl);

    PoolRequest[] poolRequests;

    for (auto i = 0; i != countThreads; ++i)
    {
        //auto request = new GetWorkersRequest(countRequestsPerThread, getWorkersUrl);
        auto request = new StatAddressRequest(countRequestsPerThread, getWorkersUrl);
        request.setVerbose(verbose);
        request.start();
        poolRequests ~= request;
    }

    int totalSucceded = 0;
    int totalFailures = 0;

    foreach (PoolRequest request; poolRequests)
    {
        request.join();

        totalSucceded += request.succeded();
        totalFailures += request.failed();
    }

    writeln(format("Testing finished. Count requests: %d, total succeded: %d, total failures: %d",
        poolRequests.length,
        totalSucceded,
        totalFailures));
}
