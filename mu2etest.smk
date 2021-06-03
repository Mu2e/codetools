
def dependencies(wildcards):
    cfg = config['tests'][wildcards.test_name]
    if 'needs' not in cfg:
        return []
    
    result = []
    for test_dep in cfg['needs']:
        if test_dep not in config['tests']:
            raise ValueError("{test_dep} not a valid test name")
        result.append(f"{test_dep}.fcl_return_code" if 'fcl' in config['tests'][test_dep] else f"{test_dep}.script_return_code")
    return result

def get_threads(w):
    if not 'cores' in config['tests'][w.test_name]:
        return 1

    if config['tests'][w.test_name]['cores'] == 'all':
        return workflow.cores 
    
    return config['tests'][w.test_name]['cores']

def get_setting(setting):
    def getter(w):
        if setting in config['tests'][w.test_name]:
            return config['tests'][w.test_name][setting]
        return ""
    return getter

def get_all_tests():
    return config['tests'].keys()


with open('all_tests.txt', 'w') as f:
    f.write(' '.join(get_all_tests()))


rule all:
    input:
        [f"{test_name}.fcl_return_code" for test_name in config['tests'].keys() if 'fcl' in config['tests'][test_name]] + \
        [f"{test_name}.script_return_code" for test_name in config['tests'].keys() if 'script' in config['tests'][test_name]]


rule mu2e_test_fcl:
    input:
        dependencies,

    output:
        #log_file="{test_name}.log",
        return_code="{test_name}.fcl_return_code"

    params:
        fcl=get_setting('fcl'),
        events=get_setting('events'),
        flags=get_setting('flags'),

    threads: get_threads

    shell: 
        """
        set +o pipefail;
        set +e;
        echo "mu2e -c {params.fcl} -n {params.events} {params.flags} > {wildcards.test_name}.log 2>&1"
        mu2e -c {params.fcl} -n {params.events} {params.flags} > {wildcards.test_name}.log  2>&1
        RC=$?
        echo "$RC" > {output.return_code}
        [[ $RC = "0" ]] && touch {wildcards.test_name}.SUCCESS || touch {wildcards.test_name}.FAILED
        exit $RC
        """


rule mu2e_test_script:
    input:
        dependencies
    
    output:
        #log_file="{test_name}.log",
        return_code="{test_name}.script_return_code"
    
    threads: get_threads

    params:
        script=get_setting('script'),
        flags=get_setting('flags'),

    shell: 
        """
        set +o pipefail;
        set +e;
        echo "{params.script} {params.flags} > {wildcards.test_name}.log 2>&1"
        {params.script} {params.flags} > {wildcards.test_name}.log  2>&1
        RC=$?
        echo "$RC" > {output.return_code}
        [[ $RC = "0" ]] && touch {wildcards.test_name}.SUCCESS || touch {wildcards.test_name}.FAILED
        exit $RC
        """


# snakemake --keep-going -s mu2etest.smk --cores all --configfile .tests.yml
