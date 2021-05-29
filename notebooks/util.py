import subprocess
from datetime import datetime, timezone
import xarray as xr
import tempfile
import pop_tools
import os

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


def zonal_mean_via_fortran(ds_in_file, var, grid=None, region_mask=None):
    """
    Write ds to a temporary netCDF file, compute zonal mean for
    a given variable based on Keith L's fortran program, read
    resulting netcdf file, and return the new xarray dataset

    If three_ocean_regions=True, use a region mask that extends the
    Pacific, Indian, and Atlantic to the coast of Antarctica (and does
    not provide separate Arctic Ocean, Lab Sea, etc regions)
    """

    # xarray doesn't require the ".nc" suffix, but it's useful to know what the file is for
#     ds_in_file = tempfile.NamedTemporaryFile(suffix='.nc')
    ds_out_file = tempfile.NamedTemporaryFile(suffix='.nc')
#     ds.to_netcdf(ds_in_file.name, format = 'NETCDF4')

    # Set up location of the zonal average executable
    za_exe = os.path.join(os.path.sep,
                          'glade',
                          'u',
                          'home',
                          'klindsay',
                          'bin',
                          'zon_avg',
                          'za')
    if grid is not None:
        grid = pop_tools.get_grid(grid)

        grid_file = tempfile.NamedTemporaryFile(suffix='.nc')
        grid_file_name = grid_file.name
        if 'region_mask_regions' in grid.attrs:
            del grid.attrs['region_mask_regions']
        grid.to_netcdf(grid_file_name)

    else:
        # Assume xarray dataset contains all needed fields
        grid_file_name = ds_in_file#.name

    if region_mask is not None:
        rmask_file = tempfile.NamedTemporaryFile(suffix='.nc')
        region_mask.to_netcdf(rmask_file.name)
        cmd_region_mask = ['-rmask_file', rmask_file.name]
    else:
        cmd_region_mask = []

    # Set up the call to za with correct options
    za_call = [za_exe, '-v', var] + cmd_region_mask + \
              ['-grid_file', grid_file_name,
               '-kmt_file', grid_file_name,
               '-O', '-o', ds_out_file.name, # -O overwrites existing file, -o gives file name
               ds_in_file]#.name]

    # Use subprocess to call za, allows us to capture stdout and print it
    proc = subprocess.Popen(za_call, stdout=subprocess.PIPE)
    (out, err) = proc.communicate()
    if not out:
        # Read in the newly-generated file
        print('za ran successfully, writing netcdf output')
        ds_out = xr.open_dataset(ds_out_file.name)
    else:
        print(f'za reported an error:\n{out.decode("utf-8")}')

    # Delete the temporary files and return the new xarray dataset
#     ds_in_file.close()
    ds_out_file.close()
    if not out:
        return(ds_out)
    return(None)


