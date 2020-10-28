import subprocess
from datetime import datetime, timezone
import xarray as xr

git_repo = (subprocess
            .check_output(['git', 'config', '--get', 'remote.origin.url'])
            .strip()
            .decode("utf-8")
            .replace('git@github.com:', 'https://github.com/')
            .replace('.git', '')            
           )

def to_netcdf_clean(dset, path, format='NETCDF3_64BIT', **kwargs):
    """wrap to_netcdf method to circumvent some xarray shortcomings"""
    
    dset = dset.copy()
    
    # ensure _FillValues are not added where they don't exist
    for v in dset.variables:
        if '_FillValue' not in dset[v].encoding:
            dset[v].encoding['_FillValue'] = None


    git_sha = subprocess.check_output(['git', 'describe', '--always']).strip().decode("utf-8")
    datestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    provenance_str = f'created by {git_repo}/tree/{git_sha} on {datestamp}'

    if 'history' in dset.attrs:
        dset.attrs['history'] += '; ' + provenance_str
    else:
        dset.attrs['history'] = provenance_str

    print('-'*30)
    print(f'Writing {path}')
    dset.info()
    print()
    dset.to_netcdf(path, format=format, **kwargs)


