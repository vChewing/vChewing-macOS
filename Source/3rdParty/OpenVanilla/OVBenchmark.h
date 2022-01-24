/* 
 *  OVBenchmark.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVBenchmark_h
#define OVBenchmark_h

#include <ctime>

namespace OpenVanilla {
    using namespace std;

    class OVBenchmark
    {
    public:
        OVBenchmark()
            : m_used(false)
            , m_running(false)
            , m_start(0)
            , m_elapsedTicks(0)
            , m_elapsedSeconds(0.0)
        {            
        }
        
    	void start()
    	{
            m_used = true;
            m_running = true;
    		m_elapsedSeconds = 0.0;
    		m_elapsedTicks = 0;
    		m_start = clock();
    	}

    	void stop()
    	{
            if (m_running) {
                update();
                m_running = false;            
    		}
    	}

    	clock_t elapsedTicks() 
    	{ 
    	    if (!m_used)
                return 0;
            
    	    if (m_running)
                update();
    	    
    	    return m_elapsedTicks;
    	}
    	
    	double elapsedSeconds()
    	{
    	    if (!m_used)
                return 0;
                
    	    if (m_running)
                update();
                
    	    return m_elapsedSeconds;
    	}

    protected:
        void update()
        {
		    m_elapsedTicks = clock() - m_start;
		    m_elapsedSeconds = static_cast<double>(m_elapsedTicks) / CLOCKS_PER_SEC;                
        }
        
        bool m_used;
        bool m_running;
    	clock_t m_start;
    	clock_t m_elapsedTicks;
    	double m_elapsedSeconds;
    };
};

#endif
