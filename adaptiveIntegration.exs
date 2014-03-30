defmodule AdaptiveIntegration do

    #calls an integration method. Currently it's supporting only simpson method
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

    def adaptive(a, b, n, tolerance, remainingIterations) do    # adaptive routine

        IO.puts "remainingIterations = #{remainingIterations}"

        if(remainingIterations == 0) do
            IO.puts "Maximum iteration provided was not enough!"
        end

        noOfProcesses = :erlang.system_info(:logical_processors_available)
        c = (a + b) / 2

        #find integrals in (a,c) , (c, b) and (a, b)
        spawn(AdaptiveIntegration, :integrationMethod, [self, 1, a, c, n, noOfProcesses])
        spawn(AdaptiveIntegration, :integrationMethod, [self, 2, c, b, n, noOfProcesses])
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
            adaptive(a,c,n,tolerance,remainingIterations-1)+adaptive(c,b,n,tolerance,remainingIterations-1)
        end
    end
end

#Simpson method which solves the integration in parallel#
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
        #IO.puts "****** #{val} ********"
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


val = AdaptiveIntegration.adaptive(0, 10, 100000, 0.0001, 1000)
IO.puts "final answer = #{val}"

