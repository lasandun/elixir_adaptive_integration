# This file contains adaptive integration using simpson method. The integration supports parallel processing.
# The integration method (simpson) runs on clusters. The adaptive method do 3 integrations in one step. Those 3 will
# aslo be done in 3 processes.
# The integrating function ( f(x) ) isn't given by a ruby program yet. Hardcoded in this file.
# The number of processes the program is generating is controlled. (not completed) 
# The available processor core quantity is calculated at the start of the program. These are system calls and 
# the occurances should be reduced as they will be time consuming.
# Currently this method is creating (processorCores x 3) processes at each step. It's better to control it to level of
# available processor cores.

defmodule AdaptiveIntegration do

    # the API to the user
    def adaptiveIntegration(a, b, n, tolerance, remainingIterations) do
        noOfProcesses = :erlang.system_info(:logical_processors_available) # get the number of usable processor cores
        adaptive(a, b, n, tolerance, remainingIterations, noOfProcesses)
    end

    # This calls one of integration methods. Curretly only simpson method is available
    def integrationMethod(pid, part, a, b, n, noOfProcesses) do 
        ret = Simpson.simpsonParallel(a, b, n, 4)
        if(part == 1) do
            send pid, {:lhs, ret}
        end
        if(part == 2) do
            send pid, {:rhs, ret}
        end
        if(part == 3) do
            send pid, {:tot, ret}
        end
    end

    def adaptive(a, b, n, tolerance, remainingIterations, noOfProcesses) do    # adaptive routine
        IO.puts "remainingIterations = #{remainingIterations}"
        if(remainingIterations == 0) do
            IO.puts "Maximum iteration provided was not enough!"
        end

        c = (a + b) / 2

        #find integrals in (a,c) , (c, b) and (a, b)
        spawn(AdaptiveIntegration, :integrationMethod, [self, 1, a, c, n/2, noOfProcesses])
        spawn(AdaptiveIntegration, :integrationMethod, [self, 2, c, b, n/2, noOfProcesses])
        spawn(AdaptiveIntegration, :integrationMethod, [self, 3, a, b, n, noOfProcesses])

        #receive results
        receive do
            {:lhs, val} -> lhs = val
            {:rhs, val} -> rhs = val
            {:tot, val} -> tot = val
        end
        receive do
            {:lhs, val} -> lhs = val
            {:rhs, val} -> rhs = val
            {:tot, val} -> tot = val
        end        
        receive do
            {:lhs, val} -> lhs = val
            {:rhs, val} -> rhs = val
            {:tot, val} -> tot = val
        end
        
        #find absolute value of the error
        temp = (lhs[:error] + rhs[:error] - tot[:error])
        if(temp <0) do
            err = -temp
        else
            err = temp
        end

        if(err < tolerance) do
            (lhs[:result] + rhs[:result])
        else
            adaptive(a,c,n,tolerance,remainingIterations-1,noOfProcesses)+adaptive(c,b,n,tolerance,remainingIterations-1,noOfProcesses)
        end
    end
end

#Simpson method which solves the integration in parallel#
#This will return [{:result, val}, {:error, error}]. The result and the error value
defmodule Simpson do
    def f(x) do
        (x*x*x*x - x*x + x*2)
    end

    def f4(x) do    #temporary method to find the error: get the fourth integration of the function
        1
    end

    def findError(a, b) do
        error = :math.pow((b-a)*0.5, 5)*f4(a/2+b/2)/90
        error
    end

    def simpson(parentPID, a, b, n) do
        if((n/2)*2 != n) do
            samples = n + 1
        else
            samples = n
        end
        
        dx = ((b-a)*1.0)/samples

        i = 2
        ret = iterate(i, samples, dx, a)
        sol = ( ret + f(a) + f(b) + 4.0 * f(a+dx) ) * dx / 3.0
        send parentPID, {:result, sol}
    end

    def iterate(i, n, dx, a) do
        if(i <= n - 1) do
            x  = a + i * dx
            ss = 2.0 * f(x) + 4.0 * f(x+dx)
            ii = i + 2
            iterate(ii, n, dx, a) + ss
        else
            0
        end
    end

    def simpsonParallel(a, b, n, noOfProcesses) do
        

        stepSize = 1.0*(b-a)/noOfProcesses
        error = findError(a, b)
        val = iteratorSP(a, n/noOfProcesses, stepSize, noOfProcesses)
        ret = [{:result, val}, {:error, error}]
        ret
    end

    def iteratorSP(a, n, stepSize, remainingIterations) do
        b = a + stepSize
        if(remainingIterations>0) do
            spawn(Simpson, :simpson, [self, a, b, n])
            nextVal = iteratorSP(b, n, stepSize, remainingIterations-1)
            receive do
                {:result, val} -> (val+nextVal)
            end
        else
            0
        end
    end
end

# calls the method. 
                                           # (a, b,  iterations, tolarence, maxIterations)
val = AdaptiveIntegration.adaptiveIntegration(0, 10, 1600000,     0.0001,      1000      )
IO.puts "final answer = #{val}"

